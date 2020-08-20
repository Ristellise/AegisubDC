// Copyright (c) 2009, Amar Takhar <verm@aegisub.org>
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

#include <cstdlib>
#include <utility>

#include "bitmap.h"
#include "default_config.h"

class wxBitmap;
class wxIcon;

wxBitmap libresrc_getimage(const unsigned char *image, size_t size);
wxBitmap libresrc_getimage_resized(const unsigned char* image, size_t size, int dir, int resize);
wxIcon libresrc_geticon(const unsigned char *image, size_t size);
#define GETIMAGE(a) libresrc_getimage(a, sizeof(a))
#define GETIMAGEDIR(a, d, s) libresrc_getimage_resized(a, sizeof(a), d, s)
#define CMD_ICON_GET(icon, dir, size) ( \
    (size) <= 16 ? GETIMAGEDIR(icon##_16, (dir), (size)) : \
    (size) <= 24 ? GETIMAGEDIR(icon##_24, (dir), (size)) : \
    (size) <= 32 ? GETIMAGEDIR(icon##_32, (dir), (size)) : \
    (size) <= 48 ? GETIMAGEDIR(icon##_48, (dir), (size)) : GETIMAGEDIR(icon##_64, (dir), (size)) )
#define GETICON(a) libresrc_geticon(a, sizeof(a))

#define GET_DEFAULT_CONFIG(a) std::make_pair(reinterpret_cast<const char *>(a), sizeof(a))
