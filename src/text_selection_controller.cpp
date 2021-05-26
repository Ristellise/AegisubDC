// Copyright (c) 2014, Thomas Goyne <plorkyeran@aegisub.org>
//
// Permission to use, copy, modify, and distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//
// Aegisub Project http://www.aegisub.org/

#include "text_selection_controller.h"

#include <wx/stc/stc.h>

void TextSelectionController::SetControl(wxStyledTextCtrl* ctrl) {
	this->ctrl_te = ctrl;
	this->ctrl_ctl = ctrl;
	if (ctrl)
		ctrl->Bind(wxEVT_STC_UPDATEUI, &TextSelectionController::UpdateUI, this);
	use_stc = true;
}

void TextSelectionController::SetControl(wxTextCtrl* ctrl) {
	this->ctrl_te = ctrl;
	this->ctrl_ctl = ctrl;
	if (ctrl) {
		ctrl->Bind(wxEVT_KEY_UP, &TextSelectionController::UpdateUI, this);
		ctrl->Bind(wxEVT_LEFT_UP, &TextSelectionController::UpdateUI, this);
	}
	use_stc = false;
}

TextSelectionController::~TextSelectionController() {
	if (ctrl_ctl) {
		if (use_stc) {
			ctrl_ctl->Unbind(wxEVT_STC_UPDATEUI, &TextSelectionController::UpdateUI, this);
		}
		else {
			ctrl_ctl->Unbind(wxEVT_KEY_UP, &TextSelectionController::UpdateUI, this);
			ctrl_ctl->Unbind(wxEVT_LEFT_UP, &TextSelectionController::UpdateUI, this);
		}
	}
}

void TextSelectionController::UpdateUI(wxEvent& evt) {
	evt.Skip();
	if (changing) return;

	bool changed = false;
	long tmp_insertion, tmp_start, tmp_end;
	tmp_insertion = ctrl_te->GetInsertionPoint();
	ctrl_te->GetSelection(&tmp_start, &tmp_end);

	if (!use_stc) {
		// GetSelection returned by wxTextCtrl is the index of Unicode codepoint position
		// We need to convert it to UTF-8 location
		tmp_insertion = ctrl_te->GetRange(0, tmp_insertion).utf8_str().length();
		tmp_start = ctrl_te->GetRange(0, tmp_start).utf8_str().length();
		tmp_end = ctrl_te->GetRange(0, tmp_end).utf8_str().length();
	}
	if (tmp_insertion != insertion_point || tmp_start != selection_start || tmp_end != selection_end) {
		insertion_point = tmp_insertion;
		selection_start = tmp_start;
		selection_end = tmp_end;
		changed = true;
	}
	if (changed) AnnounceSelectionChanged();
}

void TextSelectionController::SetInsertionPoint(long position) {
	changing = true;
	if (insertion_point != position) {
		insertion_point = position;
		if (ctrl_te) {
			long tmp_position = 0;
			if (use_stc) {
				tmp_position = position;
			}
			else {
				// Convert UTF-8 position to wxTextEdit position
				long last_position = ctrl_te->GetLastPosition();
				for (; tmp_position < last_position; ++tmp_position) {
					if (ctrl_te->GetRange(0, tmp_position).utf8_str().length() >= position) {
						break;
					}
				}
			}
			ctrl_te->SetInsertionPoint(tmp_position);
		}
	}
	changing = false;
	AnnounceSelectionChanged();
}

void TextSelectionController::SetSelection(long start, long end) {
	changing = true;
	if (selection_start != start || selection_end != end) {
		selection_start = start;
		selection_end = end;
		if (ctrl_te) {
			long tmp_start = -1, tmp_end = -1;
			if (use_stc) {
				tmp_start = start;
				tmp_end = end;
			}
			else {
				// Convert UTF-8 position to wxTextEdit position
				long last_position = ctrl_te->GetLastPosition();
				for (long pos = 0; pos < last_position; ++pos) {
					size_t pos_utf8 = ctrl_te->GetRange(0, pos).utf8_str().length();
					if (tmp_start == -1 && pos_utf8 >= start) {
						tmp_start = pos;
					}
					if (tmp_end == -1 && pos_utf8 >= end) {
						tmp_end = pos;
					}
					if (tmp_start != -1 && tmp_end != -1) {
						break;
					}
				}
				if (tmp_start == -1) {
					tmp_start = last_position;
				}
				if (tmp_end == -1) {
					tmp_end = last_position;
				}
			}
			ctrl_te->SetSelection(tmp_start, tmp_end);
		}
	}
	changing = false;
	AnnounceSelectionChanged();
}