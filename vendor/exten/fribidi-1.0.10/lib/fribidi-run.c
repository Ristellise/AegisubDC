/* FriBidi
 * fribidi-run.c - text run data type
 *
 * Authors:
 *   Behdad Esfahbod, 2001, 2002, 2004
 *   Dov Grobgeld, 1999, 2000, 2017
 *
 * Copyright (C) 2004 Sharif FarsiWeb, Inc
 * Copyright (C) 2001,2002 Behdad Esfahbod
 * Copyright (C) 1999,2000,2017 Dov Grobgeld
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library, in a file named COPYING; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA
 * 
 * For licensing issues, contact <fribidi.license@gmail.com>.
 */

#include "common.h"

#include <fribidi-bidi-types.h>

#include "run.h"
#include "bidi-types.h"

FriBidiRun *
new_run (
  void
)
{
  register FriBidiRun *run;

  run = fribidi_malloc (sizeof (FriBidiRun));

  if LIKELY
    (run)
    {
      run->len = run->pos = run->level = run->isolate_level = 0;
      run->next = run->prev = run->prev_isolate = run->next_isolate = NULL;
    }
  return run;
}

FriBidiRun *
new_run_list (
  void
)
{
  register FriBidiRun *run;

  run = new_run ();

  if LIKELY
    (run)
    {
      run->type = FRIBIDI_TYPE_SENTINEL;
      run->level = FRIBIDI_SENTINEL;
      run->pos = FRIBIDI_SENTINEL;
      run->len = FRIBIDI_SENTINEL;
      run->next = run->prev = run;
    }

  return run;
}

void
free_run_list (
  FriBidiRun *run_list
)
{
  if (!run_list)
    return;

  fribidi_validate_run_list (run_list);

  {
    register FriBidiRun *pp;

    pp = run_list;
    pp->prev->next = NULL;
    while LIKELY
      (pp)
      {
	register FriBidiRun *p;

	p = pp;
	pp = pp->next;
	fribidi_free (p);
      };
  }
}


FriBidiRun *
run_list_encode_bidi_types (
  /* input */
  const FriBidiCharType *bidi_types,
  const FriBidiBracketType *bracket_types,
  const FriBidiStrIndex len
)
{
  FriBidiRun *list, *last;
  register FriBidiRun *run = NULL;
  FriBidiStrIndex i;

  fribidi_assert (bidi_types);

  /* Create the list sentinel */
  list = new_run_list ();
  if UNLIKELY
    (!list) return NULL;
  last = list;

  /* Scan over the character types */
  for (i = 0; i < len; i++)
    {
      register FriBidiCharType char_type = bidi_types[i];
      register FriBidiBracketType bracket_type = FRIBIDI_NO_BRACKET;
      if (bracket_types)
        bracket_type = bracket_types[i];
      
      if (char_type != last->type
          || bracket_type != FRIBIDI_NO_BRACKET /* Always separate bracket into single char runs! */
          || last->bracket_type != FRIBIDI_NO_BRACKET
          || FRIBIDI_IS_ISOLATE(char_type)
          )
	{
	  run = new_run ();
	  if UNLIKELY
	    (!run) break;
	  run->type = char_type;
	  run->pos = i;
	  last->len = run->pos - last->pos;
	  last->next = run;
	  run->prev = last;
          run->bracket_type = bracket_type;
	  last = run;
	}
    }

  /* Close the circle */
  last->len = len - last->pos;
  last->next = list;
  list->prev = last;

  if UNLIKELY
    (!run)
    {
      /* Memory allocation failed */
      free_run_list (list);
      return NULL;
    }

  fribidi_validate_run_list (list);

  return list;
}

/* override the run list 'base', with the runs in the list 'over', to
   reinsert the previously-removed explicit codes (at X9) from
   'explicits_list' back into 'type_rl_list' for example. This is used at the
   end of I2 to restore the explicit marks, and also to reset the character
   types of characters at L1.

   it is assumed that the 'pos' of the first element in 'base' list is not
   more than the 'pos' of the first element of the 'over' list, and the
   'pos' of the last element of the 'base' list is not less than the 'pos'
   of the last element of the 'over' list. these two conditions are always
   satisfied for the two usages mentioned above.

   Note:
     frees the over list.

   Todo:
     use some explanatory names instead of p, q, ...
     rewrite comment above to remove references to special usage.
*/
fribidi_boolean
shadow_run_list (
  /* input */
  FriBidiRun *base,
  FriBidiRun *over,
  fribidi_boolean preserve_length
)
{
  register FriBidiRun *p = base, *q, *r, *s, *t;
  register FriBidiStrIndex pos = 0, pos2;
  fribidi_boolean status = false;

  fribidi_validate_run_list (base);
  fribidi_validate_run_list (over);

  for_run_list (q, over)
  {
    if UNLIKELY
      (!q->len || q->pos < pos) continue;
    pos = q->pos;
    while (p->next->type != FRIBIDI_TYPE_SENTINEL && p->next->pos <= pos)
      p = p->next;
    /* now p is the element that q must be inserted 'in'. */
    pos2 = pos + q->len;
    r = p;
    while (r->next->type != FRIBIDI_TYPE_SENTINEL && r->next->pos < pos2)
      r = r->next;
    if (preserve_length)
      r->len += q->len;
    /* now r is the last element that q affects. */
    if LIKELY
      (p == r)
      {
	/* split p into at most 3 intervals, and insert q in the place of
	   the second interval, set r to be the third part. */
	/* third part needed? */
	if (p->pos + p->len > pos2)
	  {
	    r = new_run ();
	    if UNLIKELY
	      (!r) goto out;
	    p->next->prev = r;
	    r->next = p->next;
	    r->level = p->level;
	    r->isolate_level = p->isolate_level;
	    r->type = p->type;
	    r->len = p->pos + p->len - pos2;
	    r->pos = pos2;
	  }
	else
	  r = r->next;

	if LIKELY
	  (p->pos + p->len >= pos)
	  {
	    /* first part needed? */
	    if (p->pos < pos)
	      /* cut the end of p. */
	      p->len = pos - p->pos;
	    else
	      {
		t = p;
		p = p->prev;
		fribidi_free (t);
	      }
	  }
      }
    else
      {
	if LIKELY
	  (p->pos + p->len >= pos)
	  {
	    /* p needed? */
	    if (p->pos < pos)
	      /* cut the end of p. */
	      p->len = pos - p->pos;
	    else
	      p = p->prev;
	  }

	/* r needed? */
	if (r->pos + r->len > pos2)
	  {
	    /* cut the beginning of r. */
	    r->len = r->pos + r->len - pos2;
	    r->pos = pos2;
	  }
	else
	  r = r->next;

	/* remove the elements between p and r. */
	for (s = p->next; s != r;)
	  {
	    t = s;
	    s = s->next;
	    fribidi_free (t);
	  }
      }
    /* before updating the next and prev runs to point to the inserted q,
       we must remember the next element of q in the 'over' list.
     */
    t = q;
    q = q->prev;
    delete_node (t);
    p->next = t;
    t->prev = p;
    t->next = r;
    r->prev = t;
  }
  status = true;

  fribidi_validate_run_list (base);

out:
  free_run_list (over);

  return status;
}

#ifdef DEBUG

void
fribidi_validate_run_list (
  FriBidiRun *run_list		/* input run list */
)
{
  register FriBidiRun *q;

  fribidi_assert (run_list);
  fribidi_assert (run_list->next);
  fribidi_assert (run_list->next->prev == run_list);
  fribidi_assert (run_list->type == FRIBIDI_TYPE_SENTINEL);
  for_run_list (q, run_list)
  {
    fribidi_assert (q->next);
    fribidi_assert (q->next->prev == q);
  }
  fribidi_assert (q == run_list);
}

#endif /* !DEBUG */

/* Editor directions:
 * vim:textwidth=78:tabstop=8:shiftwidth=2:autoindent:cindent
 */
