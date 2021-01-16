--[[
	Copyright (c) 2014, Christoph "Youka" Spanknebel

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
	-----------------------------------------------------------------------------------------------------------------
	Version: 17th January 2015, 15:45 (GMT+1)
	
	Yutils
		table
			copy(t[, depth]) -> table
			tostring(t) -> string
		utf8
			charrange(s, i) -> number
			chars(s) -> function
			len(s) -> number
		math
			arc_curve(x, y, cx, cy, angle) -> 8, 16, 24 or 32 numbers
			bezier(pct, pts) -> number, number, number
			create_matrix() -> table
				get_data() -> table
				set_data(matrix) -> table
				identity() -> table
				multiply(matrix2) -> table
				translate(x, y, z) -> table
				scale(x, y, z) -> table
				rotate(axis, angle) -> table
				inverse() -> [table]
				transform(x, y, z[, w]) -> number, number, number, number
			degree(x1, y1, z1, x2, y2, z2) -> number
			distance(x, y[, z]) -> number
			line_intersect(x0, y0, x1, y1, x2, y2, x3, y3, strict) -> number, number|nil|inf
			ortho(x1, y1, z1, x2, y2, z2) -> number, number, number
			randomsteps(min, max, step) -> number
			round(x[, dec]) -> number
			stretch(x, y, z, length) -> number, number, number
			trim(x, min, max) -> number
		algorithm
			frames(starts, ends, dur) -> function
			lines(text) -> function
		shape
			bounding(shape) -> number, number, number, number
			detect(width, height, data[, compare_func]) -> table
			filter(shape, filter) -> string
			flatten(shape) -> string
			glue(src_shape, dst_shape[, transform_callback]) -> string
			move(shape, x, y) -> string
			split(shape, max_len) -> string
			to_outline(shape, width_xy[, width_y][, mode]) -> string
			to_pixels(shape) -> table
			transform(shape, matrix) -> string
		ass
			convert_time(ass_ms) -> number|string
			convert_coloralpha(ass_r_a[, g, b[, a] ]) -> 1,3,4 numbers|string
			interpolate_coloralpha(pct, ...) -> string
			create_parser([ass_text]) -> table
				parse_line(line) -> boolean
				meta() -> table
				styles() -> table
				dialogs([extended]) -> table
		decode
			create_bmp_reader(filename) -> table
				file_size() -> number
				width() -> number
				height() -> number
				bit_depth() -> number
				data_size() -> number
				row_size() -> number
				bottom_up() -> boolean
				data_raw() -> string
				data_packed() -> table
				data_text() -> string
			create_wav_reader(filename) -> table
				file_size() -> number
				channels_number() -> number
				sample_rate() -> number
				byte_rate() -> number
				block_align() -> number
				bits_per_sample() -> number
				samples_per_channel() -> number
				min_max_amplitude() -> number, number
				sample_from_ms(ms) -> number
				ms_from_sample(sample) -> number
				position([pos]) -> number
				samples_interlaced(n) -> table
				samples(n) -> table
			create_frequency_analyzer(samples, sample_rate) -> table
				frequencies() -> table
				frequency_weight(freq) -> number
				frequency_range_weight(freq_min, freq_max) -> number
			create_font(family, bold, italic, underline, strikeout, size[, xscale][, yscale][, hspace]) -> table
				metrics() -> table
				text_extents(text) -> table
				text_to_shape(text) -> string
			list_fonts([with_filenames]) -> table
]]

-- Configuration
local FP_PRECISION = 3	-- Floating point precision by numbers behind point (for shape points)
local CURVE_TOLERANCE = 1	-- Angle in degree to define a curve as flat
local MAX_CIRCUMFERENCE = 1.5	-- Circumference step size to create round edges out of lines
local MITER_LIMIT = 200	-- Maximal length of a miter join
local SUPERSAMPLING = 8	-- Anti-aliasing precision for shape to pixels conversion
local FONT_PRECISION = 64	-- Font scale for better precision output from native font system
local LIBASS_FONTHACK = true	-- Scale font data to fontsize? (no effect on windows)
local LIBPNG_PATH = "libpng"	-- libpng dynamic library location or shortcut (for system library loading function)

-- Load FFI interface
local ffi = require("ffi")
-- Check OS & load fitting system libraries
local advapi, pangocairo, fontconfig
if ffi.os == "Windows" then
	-- WinGDI already loaded in C namespace by default
	-- Load advanced winapi library
	advapi = ffi.load("Advapi32")
	-- Set C definitions for WinAPI
	ffi.cdef([[
enum{CP_UTF8 = 65001};
enum{MM_TEXT = 1};
enum{TRANSPARENT = 1};
enum{
	FW_NORMAL = 400,
	FW_BOLD = 700
};
enum{DEFAULT_CHARSET = 1};
enum{OUT_TT_PRECIS = 4};
enum{CLIP_DEFAULT_PRECIS = 0};
enum{ANTIALIASED_QUALITY = 4};
enum{DEFAULT_PITCH = 0x0};
enum{FF_DONTCARE = 0x0};
enum{
	PT_MOVETO = 0x6,
	PT_LINETO = 0x2,
	PT_BEZIERTO = 0x4,
	PT_CLOSEFIGURE = 0x1
};
typedef unsigned int UINT;
typedef unsigned long DWORD;
typedef DWORD* LPDWORD;
typedef const char* LPCSTR;
typedef const wchar_t* LPCWSTR;
typedef wchar_t* LPWSTR;
typedef char* LPSTR;
typedef void* HANDLE;
typedef HANDLE HDC;
typedef int BOOL;
typedef BOOL* LPBOOL;
typedef unsigned int size_t;
typedef HANDLE HFONT;
typedef HANDLE HGDIOBJ;
typedef long LONG;
typedef wchar_t WCHAR;
typedef unsigned char BYTE;
typedef BYTE* LPBYTE;
typedef int INT;
typedef long LPARAM;
static const int LF_FACESIZE = 32;
static const int LF_FULLFACESIZE = 64;
typedef struct{
	LONG tmHeight;
	LONG tmAscent;
	LONG tmDescent;
	LONG tmInternalLeading;
	LONG tmExternalLeading;
	LONG tmAveCharWidth;
	LONG tmMaxCharWidth;
	LONG tmWeight;
	LONG tmOverhang;
	LONG tmDigitizedAspectX;
	LONG tmDigitizedAspectY;
	WCHAR tmFirstChar;
	WCHAR tmLastChar;
	WCHAR tmDefaultChar;
	WCHAR tmBreakChar;
	BYTE tmItalic;
	BYTE tmUnderlined;
	BYTE tmStruckOut;
	BYTE tmPitchAndFamily;
	BYTE tmCharSet;
}TEXTMETRICW, *LPTEXTMETRICW;
typedef struct{
	LONG cx;
	LONG cy;
}SIZE, *LPSIZE;
typedef struct{
	LONG left;
	LONG top;
	LONG right;
	LONG bottom;
}RECT;
typedef const RECT* LPCRECT;
typedef struct{
	LONG x;
	LONG y;
}POINT, *LPPOINT;
typedef struct{
  LONG  lfHeight;
  LONG  lfWidth;
  LONG  lfEscapement;
  LONG  lfOrientation;
  LONG  lfWeight;
  BYTE  lfItalic;
  BYTE  lfUnderline;
  BYTE  lfStrikeOut;
  BYTE  lfCharSet;
  BYTE  lfOutPrecision;
  BYTE  lfClipPrecision;
  BYTE  lfQuality;
  BYTE  lfPitchAndFamily;
  WCHAR lfFaceName[LF_FACESIZE];
}LOGFONTW, *LPLOGFONTW;
typedef struct{
  LOGFONTW elfLogFont;
  WCHAR   elfFullName[LF_FULLFACESIZE];
  WCHAR   elfStyle[LF_FACESIZE];
  WCHAR   elfScript[LF_FACESIZE];
}ENUMLOGFONTEXW, *LPENUMLOGFONTEXW;
enum{
	FONTTYPE_RASTER = 1,
	FONTTYPE_DEVICE = 2,
	FONTTYPE_TRUETYPE = 4
};
typedef int (__stdcall *FONTENUMPROC)(const ENUMLOGFONTEXW*, const void*, DWORD, LPARAM);
enum{ERROR_SUCCESS = 0};
typedef HANDLE HKEY;
typedef HKEY* PHKEY;
enum{HKEY_LOCAL_MACHINE = 0x80000002};
typedef enum{KEY_READ = 0x20019}REGSAM;

int MultiByteToWideChar(UINT, DWORD, LPCSTR, int, LPWSTR, int);
int WideCharToMultiByte(UINT, DWORD, LPCWSTR, int, LPSTR, int, LPCSTR, LPBOOL);
HDC CreateCompatibleDC(HDC);
BOOL DeleteDC(HDC);
int SetMapMode(HDC, int);
int SetBkMode(HDC, int);
size_t wcslen(const wchar_t*);
HFONT CreateFontW(int, int, int, int, int, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, LPCWSTR);
HGDIOBJ SelectObject(HDC, HGDIOBJ);
BOOL DeleteObject(HGDIOBJ);
BOOL GetTextMetricsW(HDC, LPTEXTMETRICW);
BOOL GetTextExtentPoint32W(HDC, LPCWSTR, int, LPSIZE);
BOOL BeginPath(HDC);
BOOL ExtTextOutW(HDC, int, int, UINT, LPCRECT, LPCWSTR, UINT, const INT*);
BOOL EndPath(HDC);
int GetPath(HDC, LPPOINT, LPBYTE, int);
BOOL AbortPath(HDC);
int EnumFontFamiliesExW(HDC, LPLOGFONTW, FONTENUMPROC, LPARAM, DWORD);
LONG RegOpenKeyExA(HKEY, LPCSTR, DWORD, REGSAM, PHKEY);
LONG RegCloseKey(HKEY);
LONG RegEnumValueW(HKEY, DWORD, LPWSTR, LPDWORD, LPDWORD, LPDWORD, LPBYTE, LPDWORD);
	]])
else	-- Unix
	-- Attempt to load pangocairo library
	pcall(function()
		pangocairo = ffi.load("pangocairo-1.0.so") -- Extension must be appended because of dot already in filename
		-- Set C definitions for pangocairo
		ffi.cdef([[
typedef enum{
    CAIRO_FORMAT_INVALID   = -1,
    CAIRO_FORMAT_ARGB32    = 0,
    CAIRO_FORMAT_RGB24     = 1,
    CAIRO_FORMAT_A8        = 2,
    CAIRO_FORMAT_A1        = 3,
    CAIRO_FORMAT_RGB16_565 = 4,
    CAIRO_FORMAT_RGB30     = 5
}cairo_format_t;
typedef void cairo_surface_t;
typedef void cairo_t;
typedef void PangoLayout;
typedef void* gpointer;
static const int PANGO_SCALE = 1024;
typedef void PangoFontDescription;
typedef enum{
	PANGO_WEIGHT_THIN	= 100,
	PANGO_WEIGHT_ULTRALIGHT = 200,
	PANGO_WEIGHT_LIGHT = 300,
	PANGO_WEIGHT_NORMAL = 400,
	PANGO_WEIGHT_MEDIUM = 500,
	PANGO_WEIGHT_SEMIBOLD = 600,
	PANGO_WEIGHT_BOLD = 700,
	PANGO_WEIGHT_ULTRABOLD = 800,
	PANGO_WEIGHT_HEAVY = 900,
	PANGO_WEIGHT_ULTRAHEAVY = 1000
}PangoWeight;
typedef enum{
	PANGO_STYLE_NORMAL,
	PANGO_STYLE_OBLIQUE,
	PANGO_STYLE_ITALIC
}PangoStyle;
typedef void PangoAttrList;
typedef void PangoAttribute;
typedef enum{
	PANGO_UNDERLINE_NONE,
	PANGO_UNDERLINE_SINGLE,
	PANGO_UNDERLINE_DOUBLE,
	PANGO_UNDERLINE_LOW,
	PANGO_UNDERLINE_ERROR
}PangoUnderline;
typedef int gint;
typedef gint gboolean;
typedef void PangoContext;
typedef unsigned int guint;
typedef struct{
	guint ref_count;
	int ascent;
	int descent;
	int approximate_char_width;
	int approximate_digit_width;
	int underline_position;
	int underline_thickness;
	int strikethrough_position;
	int strikethrough_thickness;
}PangoFontMetrics;
typedef void PangoLanguage;
typedef struct{
	int x;
	int y;
	int width;
	int height;
}PangoRectangle;
typedef enum{
	CAIRO_STATUS_SUCCESS = 0
}cairo_status_t;
typedef enum{
	CAIRO_PATH_MOVE_TO,
	CAIRO_PATH_LINE_TO,
	CAIRO_PATH_CURVE_TO,
	CAIRO_PATH_CLOSE_PATH
}cairo_path_data_type_t;
typedef union{
	struct{
		cairo_path_data_type_t type;
		int length;
	}header;
	struct{
		double x, y;
	}point;
}cairo_path_data_t;
typedef struct{
	cairo_status_t status;
	cairo_path_data_t* data;
	int num_data;
}cairo_path_t;

cairo_surface_t* cairo_image_surface_create(cairo_format_t, int, int);
void cairo_surface_destroy(cairo_surface_t*);
cairo_t* cairo_create(cairo_surface_t*);
void cairo_destroy(cairo_t*);
PangoLayout* pango_cairo_create_layout(cairo_t*);
void g_object_unref(gpointer);
PangoFontDescription* pango_font_description_new(void);
void pango_font_description_free(PangoFontDescription*);
void pango_font_description_set_family(PangoFontDescription*, const char*);
void pango_font_description_set_weight(PangoFontDescription*, PangoWeight);
void pango_font_description_set_style(PangoFontDescription*, PangoStyle);
void pango_font_description_set_absolute_size(PangoFontDescription*, double);
void pango_layout_set_font_description(PangoLayout*, PangoFontDescription*);
PangoAttrList* pango_attr_list_new(void);
void pango_attr_list_unref(PangoAttrList*);
void pango_attr_list_insert(PangoAttrList*, PangoAttribute*);
PangoAttribute* pango_attr_underline_new(PangoUnderline);
PangoAttribute* pango_attr_strikethrough_new(gboolean);
PangoAttribute* pango_attr_letter_spacing_new(int);
void pango_layout_set_attributes(PangoLayout*, PangoAttrList*);
PangoContext* pango_layout_get_context(PangoLayout*);
const PangoFontDescription* pango_layout_get_font_description(PangoLayout*);
PangoFontMetrics* pango_context_get_metrics(PangoContext*, const PangoFontDescription*, PangoLanguage*);
void pango_font_metrics_unref(PangoFontMetrics*);
int pango_font_metrics_get_ascent(PangoFontMetrics*);
int pango_font_metrics_get_descent(PangoFontMetrics*);
int pango_layout_get_spacing(PangoLayout*);
void pango_layout_set_text(PangoLayout*, const char*, int);
void pango_layout_get_pixel_extents(PangoLayout*, PangoRectangle*, PangoRectangle*);
void cairo_save(cairo_t*);
void cairo_restore(cairo_t*);
void cairo_scale(cairo_t*, double, double);
void pango_cairo_layout_path(cairo_t*, PangoLayout*);
void cairo_new_path(cairo_t*);
cairo_path_t* cairo_copy_path(cairo_t*);
void cairo_path_destroy(cairo_path_t*);
		]])
	end)
	-- Attempt to load fontconfig library
	pcall(function()
		fontconfig = ffi.load("fontconfig")
		-- Set C definitions for fontconfig
		ffi.cdef([[
typedef void FcConfig;
typedef void FcPattern;
typedef struct{
	int nobject;
	int sobject;
	const char** objects;
}FcObjectSet;
typedef struct{
	int nfont;
	int sfont;
	FcPattern** fonts;
}FcFontSet;
typedef enum{
	FcResultMatch,
	FcResultNoMatch,
	FcResultTypeMismatch,
	FcResultNoId,
	FcResultOutOfMemory
}FcResult;
typedef unsigned char FcChar8;
typedef int FcBool;

FcConfig* FcInitLoadConfigAndFonts(void);
FcPattern* FcPatternCreate(void);
void FcPatternDestroy(FcPattern*);
FcObjectSet* FcObjectSetBuild(const char*, ...);
void FcObjectSetDestroy(FcObjectSet*);
FcFontSet* FcFontList(FcConfig*, FcPattern*, FcObjectSet*);
void FcFontSetDestroy(FcFontSet*);
FcResult FcPatternGetString(FcPattern*, const char*, int, FcChar8**);
FcResult FcPatternGetBool(FcPattern*, const char*, int, FcBool*);
		]])
	end)
end
-- Load PNG decode library (at least try it)
local libpng
pcall(function()
	libpng = ffi.load(LIBPNG_PATH)
	-- Set C definitions for libpng
	ffi.cdef([[
static const int PNG_SIGNATURE_SIZE = 8;
typedef unsigned char png_byte;
typedef png_byte* png_bytep;
typedef const png_bytep png_const_bytep;
typedef unsigned int png_size_t;
typedef char png_char;
typedef png_char* png_charp;
typedef const png_charp png_const_charp;
typedef void png_void;
typedef png_void* png_voidp;
typedef struct png_struct* png_structp;
typedef const png_structp png_const_structp;
typedef struct png_info* png_infop;
typedef const png_infop png_const_infop;
typedef unsigned int png_uint_32;
typedef void (__cdecl *png_error_ptr)(png_structp, png_const_charp);
typedef void (__cdecl *png_rw_ptr)(png_structp, png_bytep, png_size_t);
enum{
	PNG_TRANSFORM_STRIP_16 = 0x1,
	PNG_TRANSFORM_PACKING = 0x4,
	PNG_TRANSFORM_EXPAND = 0x10,
	PNG_TRANSFORM_BGR = 0x80
};
enum{
	PNG_COLOR_MASK_COLOR = 2,
	PNG_COLOR_MASK_ALPHA = 4
};
enum{
	PNG_COLOR_TYPE_RGB = PNG_COLOR_MASK_COLOR,
	PNG_COLOR_TYPE_RGBA = PNG_COLOR_MASK_COLOR | PNG_COLOR_MASK_ALPHA
};

void* memcpy(void*, const void*, size_t);
int png_sig_cmp(png_const_bytep, png_size_t, png_size_t);
png_structp png_create_read_struct(png_const_charp, png_voidp, png_error_ptr, png_error_ptr);
void png_destroy_read_struct(png_structp*, png_infop*, png_infop*);
png_infop png_create_info_struct(png_structp);
void png_set_read_fn(png_structp, png_voidp, png_rw_ptr);
void png_read_png(png_structp, png_infop, int, png_voidp);
int png_set_interlace_handling(png_structp);
void png_read_update_info(png_structp, png_infop);
png_uint_32 png_get_image_width(png_const_structp, png_const_infop);
png_uint_32 png_get_image_height(png_const_structp, png_const_infop);
png_byte png_get_color_type(png_const_structp, png_const_infop);
png_size_t png_get_rowbytes(png_const_structp, png_const_infop);
png_bytep* png_get_rows(png_const_structp, png_const_infop);
	]])
end)

-- Helper functions
local unpack = table.unpack or unpack
local function rotate2d(x, y, angle)
	local ra = math.rad(angle)
	return math.cos(ra)*x - math.sin(ra)*y,
		math.sin(ra)*x + math.cos(ra)*y
end
local function bton(s)
	-- Get numeric presentation (=byte) of string characters
	local bytes, n = {s:byte(1,-1)}, 0
	-- Combine bytes to unsigned integer number
	for i = 0, #s-1 do
		n = n + bytes[1+i] * 256^i
	end
	return n
end
local function utf8_to_utf16(s)
	-- Get resulting utf16 characters number (+ null-termination)
	local wlen = ffi.C.MultiByteToWideChar(ffi.C.CP_UTF8, 0x0, s, -1, nil, 0)
	-- Allocate array for utf16 characters storage
	local ws = ffi.new("wchar_t[?]", wlen)
	-- Convert utf8 string to utf16 characters
	ffi.C.MultiByteToWideChar(ffi.C.CP_UTF8, 0x0, s, -1, ws, wlen)
	-- Return utf16 C string
	return ws
end
local function utf16_to_utf8(ws)
	-- Get resulting utf8 characters number (+ null-termination)
	local slen = ffi.C.WideCharToMultiByte(ffi.C.CP_UTF8, 0x0, ws, -1, nil, 0, nil, nil)
	-- Allocate array for utf8 characters storage
	local s = ffi.new("char[?]", slen)
	-- Convert utf16 string to utf8 characters
	ffi.C.WideCharToMultiByte(ffi.C.CP_UTF8, 0x0, ws, -1, s, slen, nil, nil)
	-- Return utf8 Lua string
	return ffi.string(s)
end

-- Create library table
local Yutils
Yutils = {
	-- Table sublibrary
	table = {
		-- Copies table deep
		copy = function(t, depth)
			-- Check argument
			if type(t) ~= "table" or depth ~= nil and not(type(depth) == "number" and depth >= 1) then
				error("table and optional depth expected", 2)
			end
			-- Copy & return
			local function copy_recursive(old_t)
				local new_t = {}
				for key, value in pairs(old_t) do
					new_t[key] = type(value) == "table" and copy_recursive(value) or value
				end
				return new_t
			end
			local function copy_recursive_n(old_t, depth)
				local new_t = {}
				for key, value in pairs(old_t) do
					new_t[key] = type(value) == "table" and depth >= 2 and copy_recursive_n(value, depth-1) or value
				end
				return new_t
			end
			return depth and copy_recursive_n(t, depth) or copy_recursive(t)
		end,
		-- Converts table to string
		tostring = function(t)
			-- Check argument
			if type(t) ~= "table" then
				error("table expected", 2)
			end
			-- Result storage
			local result, result_n = {}, 0
			-- Convert to string!
			local function convert_recursive(t, space)
				for key, value in pairs(t) do
					if type(key) == "string" then
						key = string.format("%q", key)
					end
					if type(value) == "string" then
						value = string.format("%q", value)
					end
					result_n = result_n + 1
					result[result_n] = string.format("%s[%s] = %s", space, key, value)
					if type(value) == "table" then
						convert_recursive(value, space .. "\t")
					end
				end
			end
			convert_recursive(t, "")
			-- Return result as string
			return table.concat(result, "\n")
		end
	},
	-- UTF8 sublibrary
	utf8 = {
--[[
		UTF32 -> UTF8
		--------------
		U-00000000 - U-0000007F:		0xxxxxxx
		U-00000080 - U-000007FF:		110xxxxx 10xxxxxx
		U-00000800 - U-0000FFFF:		1110xxxx 10xxxxxx 10xxxxxx
		U-00010000 - U-001FFFFF:		11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
		U-00200000 - U-03FFFFFF:		111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
		U-04000000 - U-7FFFFFFF:		1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
]]
		-- UTF8 character range at string codepoint
		charrange = function(s, i)
			-- Check arguments
			if type(s) ~= "string" or type(i) ~= "number" or i < 1 or i > #s then
				error("string and string index expected", 2)
			end
			-- Evaluate codepoint to range
			local byte = s:byte(i)
			return not byte and 0 or
					byte < 192 and 1 or
					byte < 224 and 2 or
					byte < 240 and 3 or
					byte < 248 and 4 or
					byte < 252 and 5 or
					6
		end,
		-- Creates iterator through UTF8 characters
		chars = function(s)
			-- Check argument
			if type(s) ~= "string" then
				error("string expected", 2)
			end
			-- Return utf8 characters iterator
			local char_i, s_pos, s_len = 0, 1, #s
			return function()
				if s_pos <= s_len then
					local cur_pos = s_pos
					s_pos = s_pos + Yutils.utf8.charrange(s, s_pos)
					if s_pos-1 <= s_len then
						char_i = char_i + 1
						return char_i, s:sub(cur_pos, s_pos-1)
					end
				end
			end
		end,
		-- Get UTF8 characters number in string
		len = function(s)
			-- Check argument
			if type(s) ~= "string" then
				error("string expected", 2)
			end
			-- Count UTF8 characters
			local n = 0
			for _ in Yutils.utf8.chars(s) do
				n = n + 1
			end
			return n
		end
	},
	-- Math sublibrary
	math = {
		-- Converts an arc to 1-4 cubic bezier curve(s)
		arc_curve = function(x, y, cx, cy, angle)
			-- Check arguments
			if type(x) ~= "number" or type(y) ~= "number" or type(cx) ~= "number" or type(cy) ~= "number" or type(angle) ~= "number" or
				angle < -360 or angle > 360 then
				error("start & center point and valid angle (-360<=x<=360) expected", 2)
			end
			-- Something to do?
			if angle ~= 0 then
				-- Factor for bezier control points distance to node points
				local kappa = 4 * (math.sqrt(2) - 1) / 3
				-- Relative points to center
				local rx0, ry0, rx1, ry1, rx2, ry2, rx3, ry3, rx03, ry03 = x - cx, y - cy
				-- Define arc clock direction & set angle to positive range
				local cw = angle > 0 and 1 or -1
				if angle < 0 then
					angle = -angle
				end
				-- Create curves in 90 degree chunks
				local curves, curves_n, angle_sum, cur_angle_pct = {}, 0, 0
				repeat
					-- Get arc end point
					cur_angle_pct = math.min(angle - angle_sum, 90) / 90
					rx3, ry3 = rotate2d(rx0, ry0, cw * 90 * cur_angle_pct)
					-- Get arc start to end vector
					rx03, ry03 = rx3 - rx0, ry3 - ry0
					-- Scale arc vector to curve node <-> control point distance
					rx03, ry03 = Yutils.math.stretch(rx03, ry03, 0, math.sqrt(Yutils.math.distance(rx03, ry03)^2/2) * kappa)
					-- Get curve control points
					rx1, ry1 = rotate2d(rx03, ry03, cw * -45 * cur_angle_pct)
					rx1, ry1 = rx0 + rx1, ry0 + ry1
					rx2, ry2 = rotate2d(-rx03, -ry03, cw * 45 * cur_angle_pct)
					rx2, ry2 = rx3 + rx2, ry3 + ry2
					-- Insert curve to output
					curves[curves_n+1], curves[curves_n+2], curves[curves_n+3], curves[curves_n+4],
					curves[curves_n+5], curves[curves_n+6], curves[curves_n+7], curves[curves_n+8] =
					cx + rx0, cy + ry0, cx + rx1, cy + ry1, cx + rx2, cy + ry2, cx + rx3, cy + ry3
					curves_n = curves_n + 8
					-- Prepare next curve
					rx0, ry0 = rx3, ry3
					angle_sum = angle_sum + 90
				until angle_sum >= angle
				-- Return curve points as tuple
				return unpack(curves)
			end
		end,
		-- Get point on n-degree bezier curve
		bezier = function(pct, pts)
			-- Check arguments
			if type(pct) ~= "number" or pct < 0 or pct > 1 or type(pts) ~= "table" then
				error("percent number and points table expected", 2)
			end
			local pts_n = #pts
			if pts_n < 2 then
				error("at least 2 points expected", 2)
			end
			for _, value in ipairs(pts) do
				if type(value[1]) ~= "number" or type(value[2]) ~= "number" or (value[3] ~= nil and type(value[3]) ~= "number") then
					error("points have to be tables with 2 or 3 numbers", 2)
				end
			end
			-- Pick a fitting fast calculation
			local pct_inv = 1 - pct
			if pts_n == 2 then	-- Linear curve
				return pct_inv * pts[1][1] + pct * pts[2][1],
						pct_inv * pts[1][2] + pct * pts[2][2],
						pts[1][3] and pts[2][3] and pct_inv * pts[1][3] + pct * pts[2][3] or 0
			elseif pts_n == 3 then	-- Quadratic curve
				return pct_inv * pct_inv * pts[1][1] + 2 * pct_inv * pct * pts[2][1] + pct * pct * pts[3][1],
						pct_inv * pct_inv * pts[1][2] + 2 * pct_inv * pct * pts[2][2] + pct * pct * pts[3][2],
						pts[1][3] and pts[2][3] and pct_inv * pct_inv * pts[1][3] + 2 * pct_inv * pct * pts[2][3] + pct * pct * pts[3][3] or 0
			elseif pts_n == 4 then	-- Cubic curve
				return pct_inv * pct_inv * pct_inv * pts[1][1] + 3 * pct_inv * pct_inv * pct * pts[2][1] + 3 * pct_inv * pct * pct * pts[3][1] + pct * pct * pct * pts[4][1],
						pct_inv * pct_inv * pct_inv * pts[1][2] + 3 * pct_inv * pct_inv * pct * pts[2][2] + 3 * pct_inv * pct * pct * pts[3][2] + pct * pct * pct * pts[4][2],
						pts[1][3] and pts[2][3] and pts[3][3] and pts[4][3] and pct_inv * pct_inv * pct_inv * pts[1][3] + 3 * pct_inv * pct_inv * pct * pts[2][3] + 3 * pct_inv * pct * pct * pts[3][3] + pct * pct * pct * pts[4][3] or 0
			else	-- pts_n > 4
				-- Factorial
				local function fac(n)
					local k = 1
					for i=2, n do
						k = k * i
					end
					return k
				end
				-- Calculate coordinate
				local ret_x, ret_y, ret_z = 0, 0, 0
				local n, bern, pt = pts_n - 1
				for i=0, n do
					pt = pts[1+i]
					-- Bernstein polynom
					bern = fac(n) / (fac(i) * fac(n - i)) *	--Binomial coefficient
							pct^i * pct_inv^(n - i)
					ret_x = ret_x + pt[1] * bern
					ret_y = ret_y + pt[2] * bern
					ret_z = ret_z + (pt[3] or 0) * bern
				end
				return ret_x, ret_y, ret_z
			end
		end,
		-- Creates 3d matrix
		create_matrix = function()
			-- Matrix data
			local matrix = {1, 0, 0, 0,
								0, 1, 0, 0,
								0, 0, 1, 0,
								0, 0, 0, 1}
			-- Matrix object
			local obj
			obj = {
				-- Get matrix data
				get_data = function()
					return Yutils.table.copy(matrix)
				end,
				-- Set matrix data
				set_data = function(new_matrix)
					-- Check arguments
					if type(new_matrix) ~= "table" or #new_matrix ~= 16 then
						error("4x4 matrix expected", 2)
					end
					for _, value in ipairs(new_matrix) do
						if type(value) ~= "number" then
							error("matrix must contain only numbers", 2)
						end
					end
					-- Replace old matrix
					matrix = Yutils.table.copy(new_matrix)
					-- Return this object
					return obj
				end,
				-- Set matrix to identity
				identity = function()
					-- Set matrix to default / no transformation
					matrix[1] = 1
					matrix[2] = 0
					matrix[3] = 0
					matrix[4] = 0
					matrix[5] = 0
					matrix[6] = 1
					matrix[7] = 0
					matrix[8] = 0
					matrix[9] = 0
					matrix[10] = 0
					matrix[11] = 1
					matrix[12] = 0
					matrix[13] = 0
					matrix[14] = 0
					matrix[15] = 0
					matrix[16] = 1
					-- Return this object
					return obj
				end,
				-- Multiplies matrix with given one
				multiply = function(matrix2)
					-- Check arguments
					if type(matrix2) ~= "table" or #matrix2 ~= 16 then
						error("4x4 matrix expected", 2)
					end
					for _, value in ipairs(matrix2) do
						if type(value) ~= "number" then
							error("matrix must contain only numbers", 2)
						end
					end
					-- Multipy matrices to create new one
					local new_matrix = {0, 0, 0, 0,
												0, 0, 0, 0,
												0, 0, 0, 0,
												0, 0, 0, 0}
					for i=1, 16 do
						for j=0, 3 do
							new_matrix[i] = new_matrix[i] + matrix[1 + (i-1) % 4 + j * 4] * matrix2[1 + math.floor((i-1) / 4) * 4 + j]
						end
					end
					-- Replace old matrix with multiply result
					matrix = new_matrix
					-- Return this object
					return obj
				end,
				-- Applies translation to matrix
				translate = function(x, y, z)
					-- Check arguments
					if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
						error("3 translation values expected", 2)
					end
					-- Add translation to matrix
					obj.multiply({1, 0, 0, 0,
									0, 1, 0, 0,
									0, 0, 1, 0,
									x, y, z, 1})
					-- Return this object
					return obj
				end,
				-- Applies scale to matrix
				scale = function(x, y, z)
					-- Check arguments
					if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
						error("3 scale factors expected", 2)
					end
					-- Add scale to matrix
					obj.multiply({x, 0, 0, 0,
									0, y, 0, 0,
									0, 0, z, 0,
									0, 0, 0, 1})
					-- Return this object
					return obj
				end,
				-- Applies rotation to matrix
				rotate = function(axis, angle)
					-- Check arguments
					if (axis ~= "x" and axis ~= "y" and axis ~= "z") or type(angle) ~= "number" then
						error("axis (as string) and angle (in degree) expected", 2)
					end
					-- Convert angle from degree to radian
					angle = math.rad(angle)
					-- Rotate by axis
					if axis == "x" then
						obj.multiply({1, 0, 0, 0,
									0, math.cos(angle), -math.sin(angle), 0,
									0, math.sin(angle), math.cos(angle), 0,
									0, 0, 0, 1})
					elseif axis == "y" then
						obj.multiply({math.cos(angle), 0, math.sin(angle), 0,
									0, 1, 0, 0,
									-math.sin(angle), 0, math.cos(angle), 0,
									0, 0, 0, 1})
					else	-- axis == "z"
						obj.multiply({math.cos(angle), -math.sin(angle), 0, 0,
									math.sin(angle), math.cos(angle), 0, 0,
									0, 0, 1, 0,
									0, 0, 0, 1})
					end
					-- Return this object
					return obj
				end,
				-- Inverses matrix
				inverse = function()
					-- Create inversion matrix
					local inv_matrix = {
						matrix[6] * matrix[11] * matrix[16] - matrix[6] * matrix[15] * matrix[12] - matrix[7] * matrix[10] * matrix[16] + matrix[7] * matrix[14] * matrix[12] +matrix[8] * matrix[10] * matrix[15] - matrix[8] * matrix[14] * matrix[11],
						-matrix[2] * matrix[11] * matrix[16] + matrix[2] * matrix[15] * matrix[12] + matrix[3] * matrix[10] * matrix[16] - matrix[3] * matrix[14] * matrix[12] - matrix[4] * matrix[10] * matrix[15] + matrix[4] * matrix[14] * matrix[11],
						matrix[2] * matrix[7] * matrix[16] - matrix[2] * matrix[15] * matrix[8] - matrix[3] * matrix[6] * matrix[16] + matrix[3] * matrix[14] * matrix[8] + matrix[4] * matrix[6] * matrix[15] - matrix[4] * matrix[14] * matrix[7],
						-matrix[2] * matrix[7] * matrix[12] + matrix[2] * matrix[11] * matrix[8] +matrix[3] * matrix[6] * matrix[12] - matrix[3] * matrix[10] * matrix[8] - matrix[4] * matrix[6] * matrix[11] + matrix[4] * matrix[10] * matrix[7],
						-matrix[5] * matrix[11] * matrix[16] + matrix[5] * matrix[15] * matrix[12] + matrix[7] * matrix[9] * matrix[16] - matrix[7] * matrix[13] * matrix[12] - matrix[8] * matrix[9] * matrix[15] + matrix[8] * matrix[13] * matrix[11],
						matrix[1] * matrix[11] * matrix[16] - matrix[1] * matrix[15] * matrix[12] - matrix[3] * matrix[9] * matrix[16] + matrix[3] * matrix[13] * matrix[12] + matrix[4] * matrix[9] * matrix[15] - matrix[4] * matrix[13] * matrix[11],
						-matrix[1] * matrix[7] * matrix[16] + matrix[1] * matrix[15] * matrix[8] + matrix[3] * matrix[5] * matrix[16] - matrix[3] * matrix[13] * matrix[8] - matrix[4] * matrix[5] * matrix[15] + matrix[4] * matrix[13] * matrix[7],
						matrix[1] * matrix[7] * matrix[12] - matrix[1] * matrix[11] * matrix[8] - matrix[3] * matrix[5] * matrix[12] + matrix[3] * matrix[9] * matrix[8] + matrix[4] * matrix[5] * matrix[11] - matrix[4] * matrix[9] * matrix[7],
						matrix[5] * matrix[10] * matrix[16] - matrix[5] * matrix[14] * matrix[12] - matrix[6] * matrix[9] * matrix[16] + matrix[6] * matrix[13] * matrix[12] + matrix[8] * matrix[9] * matrix[14] - matrix[8] * matrix[13] * matrix[10],
						-matrix[1] * matrix[10] * matrix[16] + matrix[1] * matrix[14] * matrix[12] + matrix[2] * matrix[9] * matrix[16] - matrix[2] * matrix[13] * matrix[12] - matrix[4] * matrix[9] * matrix[14] + matrix[4] * matrix[13] * matrix[10],
						matrix[1] * matrix[6] * matrix[16] - matrix[1] * matrix[14] * matrix[8] - matrix[2] * matrix[5] * matrix[16] + matrix[2] * matrix[13] * matrix[8] + matrix[4] * matrix[5] * matrix[14] - matrix[4] * matrix[13] * matrix[6],
						-matrix[1] * matrix[6] * matrix[12] + matrix[1] * matrix[10] * matrix[8] + matrix[2] * matrix[5] * matrix[12] - matrix[2] * matrix[9] * matrix[8] - matrix[4] * matrix[5] * matrix[10] + matrix[4] * matrix[9] * matrix[6],
						-matrix[5] * matrix[10] * matrix[15] + matrix[5] * matrix[14] * matrix[11] + matrix[6] * matrix[9] * matrix[15] - matrix[6] * matrix[13] * matrix[11] - matrix[7] * matrix[9] * matrix[14] + matrix[7] * matrix[13] * matrix[10],
						matrix[1] * matrix[10] * matrix[15] - matrix[1] * matrix[14] * matrix[11] - matrix[2] * matrix[9] * matrix[15] + matrix[2] * matrix[13] * matrix[11] + matrix[3] * matrix[9] * matrix[14] - matrix[3] * matrix[13] * matrix[10],
						-matrix[1] * matrix[6] * matrix[15] + matrix[1] * matrix[14] * matrix[7] + matrix[2] * matrix[5] * matrix[15] - matrix[2] * matrix[13] * matrix[7] - matrix[3] * matrix[5] * matrix[14] + matrix[3] * matrix[13] * matrix[6],
						matrix[1] * matrix[6] * matrix[11] - matrix[1] * matrix[10] * matrix[7] - matrix[2] * matrix[5] * matrix[11] + matrix[2] * matrix[9] * matrix[7] + matrix[3] * matrix[5] * matrix[10] - matrix[3] * matrix[9] * matrix[6]
					}
					-- Calculate determinant
					local det = matrix[1] * inv_matrix[1] +
									matrix[5] * inv_matrix[2] +
									matrix[9] * inv_matrix[3] +
									matrix[13] * inv_matrix[4]
					-- Matrix inversion possible?
					if det ~= 0 then
						-- Invert matrix
						det = 1 / det
						for i=1, 16 do
							matrix[i] = inv_matrix[i] * det
						end
						-- Return this object
						return obj
					end
				end,
				-- Applies matrix to point
				transform = function(x, y, z, w)
					-- Check arguments
					if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or (w ~= nil and type(w) ~= "number") then
						error("point (3 or 4 numbers) expected", 2)
					end
					-- Set 4th coordinate
					if not w then
						w = 1
					end
					-- Calculate new point
					return x * matrix[1] + y * matrix[5] + z * matrix[9] + w * matrix[13],
							x * matrix[2] + y * matrix[6] + z * matrix[10] + w * matrix[14],
							x * matrix[3] + y * matrix[7] + z * matrix[11] + w * matrix[15],
							x * matrix[4] + y * matrix[8] + z * matrix[12] + w * matrix[16]
				end
			}
			return obj
		end,
		-- Degree between two 3d vectors
		degree = function(x1, y1, z1, x2, y2, z2)
			-- Check arguments
			if type(x1) ~= "number" or type(y1) ~= "number" or type(z1) ~= "number" or
				type(x2) ~= "number" or type(y2) ~= "number" or type(z2) ~= "number" then
				error("2 vectors (as 6 numbers) expected", 2)
			end
			-- Calculate degree
			local degree = math.deg(
					math.acos(
						(x1 * x2 + y1 * y2 + z1 * z2) /
						(Yutils.math.distance(x1, y1, z1) * Yutils.math.distance(x2, y2, z2))
					)
			)
			-- Return with sign by clockwise direction
			return (x1*y2 - y1*x2) < 0 and -degree or degree
		end,
		-- Length of vector
		distance = function(x, y, z)
			-- Check arguments
			if type(x) ~= "number" or type(y) ~= "number" or z ~= nil and type(z) ~= "number" then
				error("one vector (2 or 3 numbers) expected", 2)
			end
			-- Calculate length
			return z and math.sqrt(x*x + y*y + z*z) or math.sqrt(x*x + y*y)
		end,
		line_intersect = function(x0, y0, x1, y1, x2, y2, x3, y3, strict)
			-- Check arguments
			if type(x0) ~= "number" or type(y0) ~= "number" or type(x1) ~= "number" or type(y1) ~= "number" or
				type(x2) ~= "number" or type(y2) ~= "number" or type(x3) ~= "number" or type(y3) ~= "number" or
				strict ~= nil and type(strict) ~= "boolean" then
				error("two lines and optional strictness flag expected", 2)
			end
			-- Get line vectors & check valid lengths
			local x10, y10, x32, y32 = x0 - x1, y0 - y1, x2 - x3, y2 - y3
			if x10 == 0 and y10 == 0 or x32 == 0 and y32 == 0 then
				error("lines mustn't have zero length", 2)
			end
			-- Calculate determinant and check for parallel lines
			local det = x10 * y32 - y10 * x32
			if det ~= 0 then
				-- Calculate line intersection (endless line lengths)
				local pre, post = (x0 * y1 - y0 * x1), (x2 * y3 - y2 * x3)
				local ix, iy = (pre * x32 - x10 * post) / det, (pre * y32 - y10 * post) / det
				-- Check for line intersection with given line lengths
				if strict then
					local s, t = x10 ~= 0 and (ix - x1) / x10 or (iy - y1) / y10, x32 ~= 0 and (ix - x3) / x32 or (iy - y3) / y32
					if s < 0 or s > 1 or t < 0 or t > 1 then
						return 1/0	-- inf
					end
				end
				-- Return intersection point
				return ix, iy
			end
		end,
		-- Get orthogonal vector of 2 given vectors
		ortho = function(x1, y1, z1, x2, y2, z2)
			-- Check arguments
			if type(x1) ~= "number" or type(y1) ~= "number" or type(z1) ~= "number" or
				type(x2) ~= "number" or type(y2) ~= "number" or type(z2) ~= "number" then
				error("2 vectors (as 6 numbers) expected", 2)
			end
			-- Calculate orthogonal
			return y1 * z2 - z1 * y2,
				z1 * x2 - x1 * z2,
				x1 * y2 - y1 * x2
		end,
		-- Generates a random number in given range with specific item distance
		randomsteps = function(min, max, step)
			-- Check arguments
			if type(min) ~= "number" or type(max) ~= "number" or type(step) ~= "number" or max < min or step <= 0 then
				error("minimal, maximal and step number expected", 2)
			end
			-- Generate random number
			return math.min(min + math.random(0, math.ceil((max - min) / step)) * step, max)
		end,
		-- Rounds number
		round = function(x, dec)
			-- Check argument
			if type(x) ~= "number" or dec ~= nil and type(dec) ~= "number" then
				error("number and optional number expected", 2)
			end
			-- Return number rounded to wished decimal size
			if dec and dec >= 1 then
				dec = 10^math.floor(dec)
				return math.floor(x * dec + 0.5) / dec
			else
				return math.floor(x + 0.5)
			end
		end,
		-- Scales vector to given length
		stretch = function(x, y, z, length)
			-- Check arguments
			if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or type(length) ~= "number" then
				error("vector (3d) and length expected", 2)
			end
			-- Get current vector length
			local cur_length = Yutils.math.distance(x, y, z)
			-- Scale vector to new length
			if cur_length == 0 then
				return 0, 0, 0
			else
				local factor = length / cur_length
				return x * factor, y * factor, z * factor
			end
		end,
		-- Trim number in range
		trim = function(x, min, max)
			-- Check arguments
			if type(x) ~= "number" or type(min) ~= "number" or type(max) ~= "number" then
				error("3 numbers expected", 2)
			end
			-- Limit number bigger-equal minimal value and smaller-equal maximal value
			return x < min and min or x > max and max or x
		end
	},
	-- Algorithm sublibrary
	algorithm = {
		-- Creates iterator through frame times
		frames = function(starts, ends, dur)
			-- Check arguments
			if type(starts) ~= "number" or type(ends) ~= "number" or type(dur) ~= "number" or dur == 0 then
				error("start, end and duration number expected", 2)
			end
			-- Iteration state
			local i, n = 0, math.ceil((ends - starts) / dur)
			-- Return iterator
			return function()
				i = i + 1
				if i <= n then
					local ret_starts = starts + (i-1) * dur
					local ret_ends = ret_starts + dur
					if dur < 0 and ret_ends < ends or dur > 0 and ret_ends > ends then
						ret_ends = ends
					end
					return ret_starts, ret_ends, i, n
				end
			end
		end,
		-- Creates iterator through text lines
		lines = function(text)
			-- Check argument
			if type(text) ~= "string" then
				error("string expected", 2)
			end
			-- Return iterator
			return function()
				-- Still text left?
				if text then
					-- Find possible line endings
					local cr = text:find("\r", 1, true)
					local lf = text:find("\n", 1, true)
					-- Find earliest line ending
					local text_end, next_step = #text, 0
					if lf then
						text_end, next_step = lf-1, 2
					end
					if cr then
						if not lf or cr < lf-1 then
							text_end, next_step = cr-1, 2
						elseif cr == lf-1 then
							text_end, next_step = cr-1, 3
						end
					end
					-- Cut line out & update text
					local line = text:sub(1, text_end)
					if next_step == 0 then
						text = nil
					else
						text = text:sub(text_end+next_step)
					end
					-- Return current line
					return line
				end
			end
		end
	},
	-- Shape sublibrary
	shape = {
		-- Calculates shape bounding box
		bounding = function(shape)
			-- Check argument
			if type(shape) ~= "string" then
				error("shape expected", 2)
			end
			-- Bounding data
			local x0, y0, x1, y1
			-- Calculate minimal and maximal coordinates
			Yutils.shape.filter(shape, function(x, y)
				if x0 then
					x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
				else
					x0, y0, x1, y1 = x, y, x, y
				end
			end)
			return x0, y0, x1, y1
		end,
		-- Extracts shapes by similar data in 2d data map
		detect = function(width, height, data, compare_func)
			-- Check arguments
			if type(width) ~= "number" or math.floor(width) ~= width or width < 1 or type(height) ~= "number" or math.floor(height) ~= height or height < 1 or type(data) ~= "table" or #data < width * height or (compare_func ~= nil and type(compare_func) ~= "function") then
				error("width, height, data and optional data compare function expected", 2)
			end
			-- Set default comparator
			if not compare_func then
				compare_func = function(a, b) return a == b end
			end
			-- Maximal data number to be processed
			local data_n = width * height
			-- Collect unique data elements
			local elements = {n = 1, {value = data[1]}}
			for i=2, data_n do
				for j=1, elements.n do
					if compare_func(data[i], elements[j].value) then
						goto trace_element_found
					end
				end
				elements.n = elements.n + 1
				elements[elements.n] = {value = type(data[i]) == "table" and Yutils.table.copy(data[i]) or data[i]}
				::trace_element_found::
			end
			-- Detection helper functions
			local function index_to_x(i)
				return (i-1) % width
			end
			local function index_to_y(i)
				return math.floor((i-1) / width)
			end
			local function coord_to_index(x, y)
				return 1 + x + y * width
			end
			local function find_direction(bitmap, x, y, last_direction)
				local top_left, top_right, bottom_left, bottom_right =
					x-1 >= 0 and y-1 >= 0 and bitmap[coord_to_index(x-1,y-1)] == 1 or false,
					x < width and y-1 >= 0 and bitmap[coord_to_index(x,y-1)] == 1 or false,
					x-1 >= 0 and y < height and bitmap[coord_to_index(x-1,y)] == 1 or false,
					x < width and y < height and bitmap[coord_to_index(x,y)] == 1 or false
				return last_direction == 8 and (
						bottom_left and (
							top_left and top_right and 6 or
							top_left and 8 or
							4
						) or (	-- bottom_right
							top_left and top_right and 4 or
							top_right and 8 or
							6
						)
					) or last_direction == 6 and (
						top_left and (
							top_right and bottom_right and 2 or
							top_right and 6 or
							8
						)or (	-- bottom_left
							top_right and bottom_right and 8 or
							bottom_right and 6 or
							2
						)
					) or last_direction == 2 and (
						top_left and (
							bottom_left and bottom_right and 6 or
							bottom_left and 2 or
							4
						) or (	-- top_right
							bottom_left and bottom_right and 4 or
							bottom_right and 2 or
							6
						)
					) or last_direction == 4 and (
						top_right and (
							top_left and bottom_left and 2 or
							top_left and 4 or
							8
						) or (	-- bottom_right
							top_left and bottom_left and 8 or
							bottom_left and 4 or
							2
						)
					)
			end
			local function extract_contour(bitmap, x, y, cw)
				local contour, direction = {n = 1, cw and {x1 = x, y1 = y+1, x2 = x, y2 = y, direction = 8} or {x1 = x, y1 = y, x2 = x, y2 = y+1, direction = 2}}
				repeat
					x, y = contour[contour.n].x2, contour[contour.n].y2
					direction = find_direction(bitmap, x, y, contour[contour.n].direction)
					contour.n = contour.n + 1
					contour[contour.n] = {x1 = x, y1 = y, x2 = direction == 4 and x-1 or direction == 6 and x+1 or x, y2 = direction == 8 and y-1 or direction == 2 and y+1 or y, direction = direction}
				until contour[contour.n].x2 == contour[1].x1 and contour[contour.n].y2 == contour[1].y1
				return contour
			end
			local function contour_indices(contour)
				-- Get top & bottom line of contour
				local min_y, max_y, line
				for i=1, contour.n do
					line = contour[i]
					if line.direction == 8 then
						min_y, max_y = min_y and math.min(min_y, line.y2) or line.y2, max_y and math.max(max_y, line.y2) or line.y2
					elseif line.direction == 2 then
						min_y, max_y = min_y and math.min(min_y, line.y1) or line.y1, max_y and math.max(max_y, line.y1) or line.y1
					end
				end
				-- Get indices by scanlines
				local indices, h_stops, h_stops_n, j = {n = 0}
				for y=min_y, max_y do
					h_stops, h_stops_n = {}, 0
					for i=1, contour.n do
						line = contour[i]
						if line.direction == 8 and line.y2 == y or line.direction == 2 and line.y1 == y then
							h_stops_n = h_stops_n + 1
							h_stops[h_stops_n] = line.x1
						end
					end
					table.sort(h_stops)
					for i=1, h_stops_n, 2 do
						j = coord_to_index(h_stops[i], y)
						for x_off=0, h_stops[i+1] - h_stops[i] - 1 do
							indices.n = indices.n + 1
							indices[indices.n] = j + x_off
						end
					end
				end
				return indices
			end
			local function merge_contour_lines(contour)
				local i = 1
				while i < contour.n do
					if contour[i].direction == contour[i+1].direction then
						contour[i].x2, contour[i].y2 = contour[i+1].x2, contour[i+1].y2
						table.remove(contour, i+1)
						contour.n = contour.n - 1
					else
						i = i + 1
					end
				end
				if contour.n > 1 and contour[1].direction == contour[contour.n].direction then
					contour[1].x1, contour[1].y1 = contour[contour.n].x1, contour[contour.n].y1
					table.remove(contour)
					contour.n = contour.n - 1
				end
				return contour
			end
			local function contour_to_shape(contour)
				local shape, shape_n, line = {string.format("m %d %d l", contour[1].x1, contour[1].y1)}, 1
				for i=1, contour.n do
					line = contour[i]
					shape_n = shape_n + 1
					shape[shape_n] = string.format("%d %d", line.x2, line.y2)
				end
				return table.concat(shape, " ")
			end
			-- Find shapes for elements
			local element, element_shapes, shape, shape_n, element_contour, element_hole_contour, indices, hole_indices
			local bitmap = {}
			for i=1, elements.n do
				element, element_shapes = elements[i].value, {n = 0}
				-- Create bitmap of data for current element
				for i=1, data_n do
					bitmap[i] = compare_func(data[i], element) and 1 or 0
				end
				-- Find first upper-left element of shapes
				for i=1, data_n do
					if bitmap[i] == 1 then
						-- Detect contour
						element_contour = extract_contour(bitmap, index_to_x(i), index_to_y(i), true)
						indices = contour_indices(element_contour)
						shape, shape_n = {contour_to_shape(merge_contour_lines(element_contour))}, 1
						-- Detect contour holes
						for i=1, indices.n do
							i = indices[i]
							if bitmap[i] == 0 then
								element_hole_contour = extract_contour(bitmap, index_to_x(i), index_to_y(i), false)
								hole_indices = contour_indices(element_hole_contour)
								shape_n = shape_n + 1
								shape[shape_n] = contour_to_shape(merge_contour_lines(element_hole_contour))
								for i=1, hole_indices.n do
									i = hole_indices[i]
									bitmap[i] = bitmap[i] + 1
								end
							end
						end
						-- Remove contour from bitmap
						for i=1, indices.n do
							i = indices[i]
							bitmap[i] = bitmap[i] - 1
						end
						-- Add shape to element
						element_shapes.n = element_shapes.n + 1
						element_shapes[element_shapes.n] = table.concat(shape, " ")
					end
				end
				-- Set shapes to element
				elements[i].shapes = element_shapes
			end
			-- Return shapes by element
			return elements
		end,
		-- Filters shape points
		filter = function(shape, filter)
			-- Check arguments
			if type(shape) ~= "string" or type(filter) ~= "function" then
				error("shape and filter function expected", 2)
			end
			-- Iterate through space separated tokens
			local token_start, token_end, token, token_num = 1
			local point_start, typ, x, new_point
			repeat
				token_start, token_end, token = shape:find("([^%s]+)", token_start)
				if token_start then
					-- Continue by token type / is number
					token_num = tonumber(token)
					if not token_num then
						-- Set point type
						point_start, typ, x = token_start, token
					else
						-- Set point coordinate
						if not x then
							-- Set x coordinate
							if not point_start then
								point_start = token_start
							end
							x = token_num
						else
							-- Apply filter on completed point
							x, token_num = filter(x, token_num, typ)
							-- Point to replace?
							if type(x) == "number" and type(token_num) == "number" then
								new_point = typ and string.format("%s %s %s", typ, Yutils.math.round(x, FP_PRECISION), Yutils.math.round(token_num, FP_PRECISION)) or
												string.format("%s %s", Yutils.math.round(x, FP_PRECISION), Yutils.math.round(token_num, FP_PRECISION))
								shape = string.format("%s%s%s", shape:sub(1, point_start-1), new_point, shape:sub(token_end+1))
								token_end = point_start + #new_point - 1
							end
							-- Reset point / prepare next one
							point_start, typ, x = nil
						end
					end
					-- Increase shape start position to next possible token
					token_start = token_end + 1
				end
			until not token_start
			-- Return (modified) shape
			return shape
		end,
		-- Converts shape curves to lines
		flatten = function(shape)
			-- Check argument
			if type(shape) ~= "string" then
				error("shape expected", 2)
			end
			-- 4th degree curve subdivider
			local function curve4_subdivide(x0, y0, x1, y1, x2, y2, x3, y3, pct)
				-- Calculate points on curve vectors
				local x01, y01, x12, y12, x23, y23 = (x0+x1)*pct, (y0+y1)*pct, (x1+x2)*pct, (y1+y2)*pct, (x2+x3)*pct, (y2+y3)*pct
				local x012, y012, x123, y123 = (x01+x12)*pct, (y01+y12)*pct, (x12+x23)*pct, (y12+y23)*pct
				local x0123, y0123 = (x012+x123)*pct, (y012+y123)*pct
				-- Return new 2 curves
				return x0, y0, x01, y01, x012, y012, x0123, y0123,
						x0123, y0123, x123, y123, x23, y23, x3, y3
			end
			-- Check flatness of 4th degree curve with angles
			local function curve4_is_flat(x0, y0, x1, y1, x2, y2, x3, y3, tolerance)
				-- Pack curve vectors
				local vecs = {{x1 - x0, y1 - y0}, {x2 - x1, y2 - y1}, {x3 - x2, y3 - y2}}
				-- Remove zero length vectors
				local i, n = 1, #vecs
				while i <= n do
					if vecs[i][1] == 0 and vecs[i][2] == 0 then
						table.remove(vecs, i)
						n = n - 1
					else
						i = i + 1
					end
				end
				-- Check flatness on remaining vectors
				for i=2, n do
					if math.abs(Yutils.math.degree(vecs[i-1][1], vecs[i-1][2], 0, vecs[i][1], vecs[i][2], 0)) > tolerance then
						return false
					end
				end
				return true
			end
			-- Convert 4th degree curve to line points
			local function curve4_to_lines(x0, y0, x1, y1, x2, y2, x3, y3)
				-- Line points buffer
				local pts, pts_n = {x0, y0}, 2
				-- Conversion in recursive processing
				local function convert_recursive(x0, y0, x1, y1, x2, y2, x3, y3)
					if curve4_is_flat(x0, y0, x1, y1, x2, y2, x3, y3, CURVE_TOLERANCE) then
						pts[pts_n+1] = x3
						pts[pts_n+2] = y3
						pts_n = pts_n + 2
					else
						local x10, y10, x11, y11, x12, y12, x13, y13, x20, y20, x21, y21, x22, y22, x23, y23 = curve4_subdivide(x0, y0, x1, y1, x2, y2, x3, y3, 0.5)
						convert_recursive(x10, y10, x11, y11, x12, y12, x13, y13)
						convert_recursive(x20, y20, x21, y21, x22, y22, x23, y23)
					end
				end
				convert_recursive(x0, y0, x1, y1, x2, y2, x3, y3)
				-- Return resulting points
				return pts
			end
			-- Search for curves
			local curves_start, curves_end, x0, y0 = 1
			local curve_start, curve_end, x1, y1, x2, y2, x3, y3
			local line_points, line_curve
			repeat
				curves_start, curves_end, x0, y0 = shape:find("([^%s]+)%s+([^%s]+)%s+b%s+", curves_start)
				x0, y0 = tonumber(x0), tonumber(y0)
				-- Curve(s) found!
				if x0 and y0 then
					-- Replace curves type by lines type
					shape = shape:sub(1, curves_start-1) .. shape:sub(curves_start):gsub("b", "l", 1)
					-- Search for single curves
					curve_start = curves_end + 1
					repeat
						curve_start, curve_end, x1, y1, x2, y2, x3, y3 = shape:find("([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)", curve_start)
						x1, y1, x2, y2, x3, y3 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2), tonumber(x3), tonumber(y3)
						if x1 and y1 and x2 and y2 and x3 and y3 then
							-- Convert curve to lines
							local line_points = curve4_to_lines(x0, y0, x1, y1, x2, y2, x3, y3)
							for i=1, #line_points do
								line_points[i] = Yutils.math.round(line_points[i], FP_PRECISION)
							end
							line_curve = table.concat(line_points, " ")
							shape = string.format("%s%s%s", shape:sub(1, curve_start-1), line_curve, shape:sub(curve_end+1))
							curve_end = curve_start + #line_curve - 1
							-- Set next start point to current last point
							x0, y0 = x3, y3
							-- Increase search start position to next possible curve
							curve_start = curve_end + 1
						end
					until not (x1 and y1 and x2 and y2 and x3 and y3)
					-- Increase search start position to next possible curves
					curves_start = curves_end + 1
				end
			until not (x0 and y0)
			-- Return shape without curves
			return shape
		end,
		-- Projects shape on shape
		glue = function(src_shape, dst_shape, transform_callback)
			-- Check arguments
			if type(src_shape) ~= "string" or type(dst_shape) ~= "string" or (transform_callback ~= nil and type(transform_callback) ~= "function") then
				error("2 shapes and optional callback function expected", 2)
			end
			-- Trim destination shape to first figure
			local _, figure_end = dst_shape:find("^%s*m.-m")
			if figure_end then
				dst_shape = dst_shape:sub(1, figure_end - 1)
			end
			-- Collect destination shape/figure lines + lengths
			local dst_lines, dst_lines_n = {}, 0
			local dst_lines_length, dst_line, last_point = 0
			Yutils.shape.filter(Yutils.shape.flatten(dst_shape), function(x, y)
				if last_point then
					dst_line = {last_point[1], last_point[2], x - last_point[1], y - last_point[2], Yutils.math.distance(x - last_point[1], y - last_point[2])}
					if dst_line[5] > 0 then
						dst_lines_n = dst_lines_n + 1
						dst_lines[dst_lines_n] = dst_line
						dst_lines_length = dst_lines_length + dst_line[5]
					end
				end
				last_point = {x, y}
			end)
			-- Any destination line?
			if dst_lines_n > 0 then
				-- Add relative positions to destination lines
				local cur_length = 0
				for _, dst_line in ipairs(dst_lines) do
					dst_line[6] = cur_length / dst_lines_length
					cur_length = cur_length + dst_line[5]
					dst_line[7] = cur_length / dst_lines_length
				end
				-- Get source shape exact bounding box
				local x0, _, x1, y1 = Yutils.shape.bounding(Yutils.shape.flatten(src_shape))
				-- Source shape has body?
				if x0 and x1 > x0 then
					-- Source shape width
					local w = x1 - x0
					-- Shift source shape on destination shape
					local x_pct, y_off, x_pct_temp, y_off_temp
					local dst_line_pos, ovec_x, ovec_y
					return Yutils.shape.filter(src_shape, function(x, y)
						-- Get relative source point to baseline
						x_pct, y_off = (x - x0) / w, y - y1
						if transform_callback then
							x_pct_temp, y_off_temp = transform_callback(x_pct, y_off)
							if type(x_pct_temp) == "number" and type(y_off_temp) == "number" then
								x_pct, y_off = math.max(0, math.min(x_pct_temp, 1)), y_off_temp
							end
						end
						-- Search for destination point, relative to source point
						for i=1, dst_lines_n do
							dst_line = dst_lines[i]
							if x_pct >= dst_line[6] and x_pct <= dst_line[7] then
								dst_line_pos = (x_pct - dst_line[6]) / (dst_line[7] - dst_line[6])
								-- Span orthogonal vector to baseline for final source to destination projection
								ovec_x, ovec_y = Yutils.math.ortho(dst_line[3], dst_line[4], 0, 0, 0, -1)
								ovec_x, ovec_y = Yutils.math.stretch(ovec_x, ovec_y, 0, y_off)
								return dst_line[1] + dst_line_pos * dst_line[3] + ovec_x,
										dst_line[2] + dst_line_pos * dst_line[4] + ovec_y
							end
						end
					end)
				end
			end
		end,
		-- Shifts shape coordinates
		move = function(shape, x, y)
			-- Check arguments
			if type(shape) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then
				error("shape, horizontal shift and vertical shift expected", 2)
			end
			-- Shift!
			return Yutils.shape.filter(shape, function(cx, cy)
				return cx + x, cy + y
			end)
		end,
		-- Splits shape lines into shorter segments
		split = function(shape, max_len)
			-- Check arguments
			if type(shape) ~= "string" or type(max_len) ~= "number" or max_len <= 0 then
				error("shape and maximal line length expected", 2)
			end
			-- Remove shape closings (figures become line-completed)
			shape = shape:gsub("%s+c", "")
			-- Line splitter + string encoder
			local function line_split(x0, y0, x1, y1)
				-- Line direction & length
				local rel_x, rel_y = x1 - x0, y1 - y0
				local distance = Yutils.math.distance(rel_x, rel_y)
				-- Line too long -> split!
				if distance > max_len then
					-- Generate line segments
					local lines, lines_n, distance_rest, pct = {}, 0, distance % max_len
					for cur_distance = distance_rest > 0 and distance_rest or max_len, distance, max_len do
						pct = cur_distance / distance
						lines_n = lines_n + 1
						lines[lines_n] = string.format("%s %s", Yutils.math.round(x0 + rel_x * pct, FP_PRECISION), Yutils.math.round(y0 + rel_y * pct, FP_PRECISION))
					end
					return table.concat(lines, " ")
				-- No line split
				else
					return string.format("%s %s", Yutils.math.round(x1, FP_PRECISION), Yutils.math.round(y1, FP_PRECISION))
				end
			end
			-- Build new shape with shorter lines
			local new_shape, new_shape_n = {}, 0
			local line_mode, last_point, last_move
			Yutils.shape.filter(shape, function(x, y, typ)
				-- Close last figure of new shape
				if typ == "m" and last_move and not (last_point[1] == last_move[1] and last_point[2] == last_move[2]) then
					if not line_mode then
						new_shape_n = new_shape_n + 1
						new_shape[new_shape_n] =  "l"
					end
					new_shape_n = new_shape_n + 1
					new_shape[new_shape_n] = line_split(last_point[1], last_point[2], last_move[1], last_move[2])
				end
				-- Add current type to new shape
				if typ then
					new_shape_n = new_shape_n + 1
					new_shape[new_shape_n] = typ
				end
				-- En-/disable line mode by current type
				if typ then
					line_mode = typ == "l"
				end
				-- Add current point or splitted line to new shape
				new_shape_n = new_shape_n + 1
				new_shape[new_shape_n] = line_mode and last_point and line_split(last_point[1], last_point[2], x, y) or string.format("%s %s", Yutils.math.round(x, FP_PRECISION), Yutils.math.round(y, FP_PRECISION))
				-- Update last point & move
				last_point = {x, y}
				if typ == "m" then
					last_move = {x, y}
				end
			end)
			-- Close last figure of new shape
			if last_move and not (last_point[1] == last_move[1] and last_point[2] == last_move[2]) then
				if not line_mode then
					new_shape_n = new_shape_n + 1
					new_shape[new_shape_n] =  "l"
				end
				new_shape_n = new_shape_n + 1
				new_shape[new_shape_n] = line_split(last_point[1], last_point[2], last_move[1], last_move[2])
			end
			return table.concat(new_shape, " ")
		end,
		-- Converts shape to stroke version
		to_outline = function(shape, width_xy, width_y, mode)
			-- Check arguments
			if type(shape) ~= "string" or type(width_xy) ~= "number" or width_y ~= nil and type(width_y) ~= "number" or mode ~= nil and type(mode) ~= "string" then
				error("shape, line width (general or horizontal and vertical) and optional mode expected", 2)
			elseif width_y and (width_xy < 0 or width_y < 0 or not (width_xy > 0 or width_y > 0)) or width_xy <= 0 then
				error("one width must be >0", 2)
			elseif mode and mode ~= "round" and mode ~= "bevel" and mode ~= "miter" then
				error("valid mode expected", 2)
			end
			-- Line width values
			local width, xscale, yscale
			if width_y and width_xy ~= width_y then
				width = math.max(width_xy, width_y)
				xscale, yscale = width_xy / width, width_y / width
			else
				width, xscale, yscale = width_xy, 1, 1
			end
			-- Collect figures
			local figures, figures_n, figure, figure_n = {}, 0, {}, 0
			local last_move
			Yutils.shape.filter(shape, function(x, y, typ)
				-- Check point type
				if typ and not (typ == "m" or typ == "l") then
					error("shape have to contain only \"moves\" and \"lines\"", 2)
				end
				-- New figure?
				if not last_move or typ == "m" then
					-- Enough points in figure?
					if figure_n > 2 then
						-- Last point equal to first point? (yes: remove him)
						if last_move and figure[figure_n][1] == last_move[1] and figure[figure_n][2] == last_move[2] then
							figure[figure_n] = nil
						end
						-- Save figure
						figures_n = figures_n + 1
						figures[figures_n] = figure
					end
					-- Clear figure for new one
					figure, figure_n = {}, 0
					-- Save last move for figure closing check
					last_move = {x, y}
				end
				-- Add point to current figure (if not copy of last)
				if figure_n == 0 or not(figure[figure_n][1] == x and figure[figure_n][2] == y) then
					figure_n = figure_n + 1
					figure[figure_n] = {x, y}
				end
			end)
			-- Insert last figure (with enough points)
			if figure_n > 2 then
				-- Last point equal to first point? (yes: remove him)
				if last_move and figure[figure_n][1] == last_move[1] and figure[figure_n][2] == last_move[2] then
					figure[figure_n] = nil
				end
				-- Save figure
				figures_n = figures_n + 1
				figures[figures_n] = figure
			end
			-- Create stroke shape out of figures
			local stroke_shape, stroke_shape_n = {}, 0
			for fi, figure in ipairs(figures) do
				-- One pass for inner, one for outer outline
				for i = 1, 2 do
					-- Outline buffer
					local outline, outline_n = {}, 0
					-- Point iteration order = inner or outer outline
					local loop_begin, loop_end, loop_steps
					if i == 1 then
						loop_begin, loop_end, loop_step = #figure, 1, -1
					else
						loop_begin, loop_end, loop_step = 1, #figure, 1
					end
					-- Iterate through figure points
					for pi = loop_begin, loop_end, loop_step do
						-- Collect current, previous and next point
						local point = figure[pi]
						local pre_point, post_point
						if i == 1 then
							if pi == 1 then
								pre_point = figure[pi+1]
								post_point = figure[#figure]
							elseif pi == #figure then
								pre_point = figure[1]
								post_point = figure[pi-1]
							else
								pre_point = figure[pi+1]
								post_point = figure[pi-1]
							end
						else
							if pi == 1 then
								pre_point = figure[#figure]
								post_point = figure[pi+1]
							elseif pi == #figure then
								pre_point = figure[pi-1]
								post_point = figure[1]
							else
								pre_point = figure[pi-1]
								post_point = figure[pi+1]
							end
						end
						-- Calculate orthogonal vectors to both neighbour points
						local vec1_x, vec1_y, vec2_x, vec2_y = point[1]-pre_point[1], point[2]-pre_point[2], point[1]-post_point[1], point[2]-post_point[2]
						local o_vec1_x, o_vec1_y = Yutils.math.ortho(vec1_x, vec1_y, 0, 0, 0, 1)
						o_vec1_x, o_vec1_y = Yutils.math.stretch(o_vec1_x, o_vec1_y, 0, width)
						local o_vec2_x, o_vec2_y = Yutils.math.ortho(vec2_x, vec2_y, 0, 0, 0, -1)
						o_vec2_x, o_vec2_y = Yutils.math.stretch(o_vec2_x, o_vec2_y, 0, width)
						-- Check for gap or edge join
						local is_x, is_y = Yutils.math.line_intersect(point[1] + o_vec1_x - vec1_x, point[2] + o_vec1_y - vec1_y,
																					point[1] + o_vec1_x, point[2] + o_vec1_y,
																					point[1] + o_vec2_x - vec2_x, point[2] + o_vec2_y - vec2_y,
																					point[1] + o_vec2_x, point[2] + o_vec2_y,
																					true)
						if is_y then
							-- Add gap point
							outline_n = outline_n + 1
							outline[outline_n] = string.format("%s%s %s",
																		outline_n == 1 and "m " or outline_n == 2 and "l " or "",
																		Yutils.math.round(point[1] + (is_x - point[1]) * xscale, FP_PRECISION), Yutils.math.round(point[2] + (is_y - point[2]) * yscale, FP_PRECISION))
						else
							-- Add first edge point
							outline_n = outline_n + 1
							outline[outline_n] = string.format("%s%s %s",
																		outline_n == 1 and "m " or outline_n == 2 and "l " or "",
																		Yutils.math.round(point[1] + o_vec1_x * xscale, FP_PRECISION), Yutils.math.round(point[2] + o_vec1_y * yscale, FP_PRECISION))
							-- Create join by mode
							if mode == "bevel" then
								-- Nothing to add!
							elseif mode == "miter" then
								-- Add mid edge point(s)
								is_x, is_y = Yutils.math.line_intersect(point[1] + o_vec1_x - vec1_x, point[2] + o_vec1_y - vec1_y,
																					point[1] + o_vec1_x, point[2] + o_vec1_y,
																					point[1] + o_vec2_x - vec2_x, point[2] + o_vec2_y - vec2_y,
																					point[1] + o_vec2_x, point[2] + o_vec2_y)
								if is_y then	-- Vectors intersect
									local is_vec_x, is_vec_y = is_x - point[1], is_y - point[2]
									local is_vec_len = Yutils.math.distance(is_vec_x, is_vec_y)
									if is_vec_len > MITER_LIMIT then
										local fix_scale = MITER_LIMIT / is_vec_len
										outline_n = outline_n + 1
										outline[outline_n] = string.format("%s%s %s %s %s",
																					outline_n == 2 and "l " or "",
																					Yutils.math.round(point[1] + (o_vec1_x + (is_vec_x - o_vec1_x) * fix_scale) * xscale, FP_PRECISION), Yutils.math.round(point[2] + (o_vec1_y + (is_vec_y - o_vec1_y) * fix_scale) * yscale, FP_PRECISION),
																					Yutils.math.round(point[1] + (o_vec2_x + (is_vec_x - o_vec2_x) * fix_scale) * xscale, FP_PRECISION), Yutils.math.round(point[2] + (o_vec2_y + (is_vec_y - o_vec2_y) * fix_scale) * yscale, FP_PRECISION))
									else
										outline_n = outline_n + 1
										outline[outline_n] = string.format("%s%s %s",
																					outline_n == 2 and "l " or "",
																					Yutils.math.round(point[1] + is_vec_x * xscale, FP_PRECISION), Yutils.math.round(point[2] + is_vec_y * yscale, FP_PRECISION))
									end
								else	-- Parallel vectors
									vec1_x, vec1_y = Yutils.math.stretch(vec1_x, vec1_y, 0, MITER_LIMIT)
									vec2_x, vec2_y = Yutils.math.stretch(vec2_x, vec2_y, 0, MITER_LIMIT)
									outline_n = outline_n + 1
									outline[outline_n] = string.format("%s%s %s %s %s",
																				outline_n == 2 and "l " or "",
																				Yutils.math.round(point[1] + (o_vec1_x + vec1_x) * xscale, FP_PRECISION), Yutils.math.round(point[2] + (o_vec1_y + vec1_y) * yscale, FP_PRECISION),
																				Yutils.math.round(point[1] + (o_vec2_x + vec2_x) * xscale, FP_PRECISION), Yutils.math.round(point[2] + (o_vec2_y + vec2_y) * yscale, FP_PRECISION))
								end
							else	-- not mode or mode == "round"
								-- Calculate degree & circumference between orthogonal vectors
								local degree = Yutils.math.degree(o_vec1_x, o_vec1_y, 0, o_vec2_x, o_vec2_y, 0)
								local circ = math.abs(math.rad(degree)) * width
								-- Join needed?
								if circ > MAX_CIRCUMFERENCE then
									-- Add curve edge points
									local circ_rest = circ % MAX_CIRCUMFERENCE
									for cur_circ = circ_rest > 0 and circ_rest or MAX_CIRCUMFERENCE, circ - MAX_CIRCUMFERENCE, MAX_CIRCUMFERENCE do
										local curve_vec_x, curve_vec_y = rotate2d(o_vec1_x, o_vec1_y, cur_circ / circ * degree)
										outline_n = outline_n + 1
										outline[outline_n] = string.format("%s%s %s",
																					outline_n == 2 and "l " or "",
																					Yutils.math.round(point[1] + curve_vec_x * xscale, FP_PRECISION), Yutils.math.round(point[2] + curve_vec_y * yscale, FP_PRECISION))
									end
								end
							end
							-- Add end edge point
							outline_n = outline_n + 1
							outline[outline_n] = string.format("%s%s %s",
																		outline_n == 2 and "l " or "",
																		Yutils.math.round(point[1] + o_vec2_x * xscale, FP_PRECISION), Yutils.math.round(point[2] + o_vec2_y * yscale, FP_PRECISION))
						end
					end
					-- Insert inner or outer outline to stroke shape
					stroke_shape_n = stroke_shape_n + 1
					stroke_shape[stroke_shape_n] = table.concat(outline, " ")
				end
			end
			return table.concat(stroke_shape, " ")
		end,
		-- Converts shape to pixels
		to_pixels = function(shape)
			-- Check argument
			if type(shape) ~= "string" then
				error("shape expected", 2)
			end
			-- Scale values for supersampled rendering
			local upscale = SUPERSAMPLING
			local downscale = 1 / upscale
			-- Upscale shape for later downsampling
			shape = Yutils.shape.filter(shape, function(x, y)
				return x * upscale, y * upscale
			end)
			-- Get shape bounding
			local x1, y1, x2, y2 = Yutils.shape.bounding(shape)
			if not y2 then
				error("not enough shape points", 2)
			end
			-- Bring shape near origin in positive room
			local shift_x, shift_y = -(x1 - x1 % upscale), -(y1 - y1 % upscale)
			shape = Yutils.shape.move(shape, shift_x, shift_y)
			-- Renderer (on binary image with aliasing)
			local function render_shape(width, height, image, shape)
				-- Collect lines (points + vectors)
				local lines, lines_n, last_point, last_move = {}, 0
				Yutils.shape.filter(Yutils.shape.flatten(shape), function(x, y, typ)
					x, y = Yutils.math.round(x), Yutils.math.round(y)	-- Use integers to avoid rounding errors
					-- Move
					if typ == "m" then
						-- Close figure with non-horizontal line in image
						if last_move and last_move[2] ~= last_point[2] and not (last_point[2] < 0 and last_move[2] < 0) and not (last_point[2] > height and last_move[2] > height) then
							lines_n = lines_n + 1
							lines[lines_n] = {last_point[1], last_point[2], last_move[1] - last_point[1], last_move[2] - last_point[2]}
						end
						last_move = {x, y}
					-- Non-horizontal line in image
					elseif last_point and last_point[2] ~= y and not (last_point[2] < 0 and y < 0) and not (last_point[2] > height and y > height) then
						lines_n = lines_n + 1
						lines[lines_n] = {last_point[1], last_point[2], x - last_point[1], y - last_point[2]}
					end
					-- Remember last point
					last_point = {x, y}
				end)
				-- Close last figure with non-horizontal line in image
				if last_move and last_move[2] ~= last_point[2] and not (last_point[2] < 0 and last_move[2] < 0) and not (last_point[2] > height and last_move[2] > height) then
					lines_n = lines_n + 1
					lines[lines_n] = {last_point[1], last_point[2], last_move[1] - last_point[1], last_move[2] - last_point[2]}
				end
				-- Calculates line x horizontal line intersection
				local function line_x_hline(x, y, vx, vy, y2)
					if vy ~= 0 then
						local s = (y2 - y) / vy
						if s >= 0 and s <= 1 then
							return x + s * vx, y2
						end
					end
				end
				-- Scan image rows in shape
				local _, y1, _, y2 = Yutils.shape.bounding(shape)
				for y = math.max(math.floor(y1), 0), math.min(math.ceil(y2), height)-1 do
					-- Collect row intersections with lines
					local row_stops, row_stops_n = {}, 0
					for i=1, lines_n do
						local line = lines[i]
						local cx = line_x_hline(line[1], line[2], line[3], line[4], y + 0.5)
						if cx then
							row_stops_n = row_stops_n + 1
							row_stops[row_stops_n] = {Yutils.math.trim(cx, 0, width), line[4] > 0 and 1 or -1}	-- image trimmed stop position & line vertical direction
						end
					end
					-- Enough intersections / something to render?
					if row_stops_n > 1 then
						-- Sort row stops by horizontal position
						table.sort(row_stops, function(a, b)
							return a[1] < b[1]
						end)
						-- Render!
						local status, row_index = 0, 1 + y * width
						for i = 1, row_stops_n-1 do
							status = status + row_stops[i][2]
							if status ~= 0 then
								for x=math.ceil(row_stops[i][1]-0.5), math.floor(row_stops[i+1][1]+0.5)-1 do
									image[row_index + x] = true
								end
							end
						end
					end
				end
			end
			-- Create image
			local img_width, img_height, img_data = math.ceil((x2 + shift_x) * downscale) * upscale, math.ceil((y2 + shift_y) * downscale) * upscale, {}
			for i=1, img_width*img_height do
				img_data[i] = false
			end
			-- Render shape on image
			render_shape(img_width, img_height, img_data, shape)
			-- Extract pixels from image
			local pixels, pixels_n, opacity = {}, 0
			for y=0, img_height-upscale, upscale do
				for x=0, img_width-upscale, upscale do
					opacity = 0
					for yy=0, upscale-1 do
						for xx=0, upscale-1 do
							if img_data[1 + (y+yy) * img_width + (x+xx)] then
								opacity = opacity + 255
							end
						end
					end
					if opacity > 0 then
						pixels_n = pixels_n + 1
						pixels[pixels_n] = {
							alpha = opacity * (downscale * downscale),
							x = (x - shift_x) * downscale,
							y = (y - shift_y) * downscale
						}
					end
				end
			end
			return pixels
		end,
		-- Applies matrix to shape coordinates
		transform = function(shape, matrix)
			-- Check arguments
			if type(shape) ~= "string" or type(matrix) ~= "table" or type(matrix.transform) ~= "function" then
				error("shape and matrix expected", 2)
			end
			local success, x, y, z, w = pcall(matrix.transform, 1, 1, 1)
			if not success or type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or type(w) ~= "number" then
				error("matrix transform method invalid", 2)
			end
			-- Filter shape with matrix
			return Yutils.shape.filter(shape, function(x, y)
				x, y, z, w = matrix.transform(x, y, 0)
				return x / w, y / w
			end)
		end
	},
	-- Advanced substation alpha sublibrary
	ass = {
		-- Converts between milliseconds and ASS timestamp
		convert_time = function(ass_ms)
			-- Process by argument
			if type(ass_ms) == "number" and ass_ms >= 0 then	-- Milliseconds
				return string.format("%d:%02d:%02d.%02d",
											math.floor(ass_ms / 3600000) % 10,
											math.floor(ass_ms % 3600000 / 60000),
											math.floor(ass_ms % 60000 / 1000),
											math.floor(ass_ms % 1000 / 10))
			elseif type(ass_ms) == "string" and ass_ms:find("^%d:%d%d:%d%d%.%d%d$") then	-- ASS timestamp
				return ass_ms:sub(1,1) * 3600000 + ass_ms:sub(3,4) * 60000 + ass_ms:sub(6,7) * 1000 + ass_ms:sub(9,10) * 10
			else
				error("milliseconds or ASS timestamp expected", 2)
			end
		end,
		-- Converts between color &/+ alpha numeric and ASS color &/+ alpha
		convert_coloralpha = function(ass_r_a, g, b, a)
			-- Process by argument(s)
			if type(ass_r_a) == "number" and ass_r_a >= 0 and ass_r_a <= 255 then	-- Alpha / red numeric
				if type(g) == "number" and g >= 0 and g <= 255 and type(b) == "number" and b >= 0 and b <= 255 then	-- Green + blue numeric
					if type(a) == "number" and a >= 0 and a <= 255 then	-- Alpha numeric
						return string.format("&H%02X%02X%02X%02X", 255 - a, b, g, ass_r_a)
					else
						return string.format("&H%02X%02X%02X&", b, g, ass_r_a)
					end
				else
					return string.format("&H%02X&", 255 - ass_r_a)
				end
			elseif type(ass_r_a) == "string" then	-- ASS value
				if ass_r_a:find("^&H%x%x&$") then	-- ASS alpha
					return 255 - tonumber(ass_r_a:sub(3,4), 16)
				elseif ass_r_a:find("^&H%x%x%x%x%x%x&$") then	-- ASS color
					return tonumber(ass_r_a:sub(7,8), 16), tonumber(ass_r_a:sub(5,6), 16), tonumber(ass_r_a:sub(3,4), 16)
				elseif ass_r_a:find("^&H%x%x%x%x%x%x%x%x$") then	-- ASS color+alpha (style)
					return tonumber(ass_r_a:sub(9,10), 16), tonumber(ass_r_a:sub(7,8), 16), tonumber(ass_r_a:sub(5,6), 16), 255 - tonumber(ass_r_a:sub(3,4), 16)
				else
					error("invalid string")
				end
			else
				error("color, alpha or color+alpha as numeric or ASS expected", 2)
			end
		end,
		-- Interpolates between two ASS colors &/+ alphas
		interpolate_coloralpha = function(pct, ...)
			-- Pack arguments
			local args = {...}
			args.n = #args
			-- Check arguments
			if type(pct) ~= "number" or pct < 0 or pct > 1 or args.n < 2 then
				error("progress and at least two ASS values of same type (color, alpha or color+alpha) expected", 2)
			end
			for i=1, args.n do
				if type(args[i]) ~= "string" then
					error("ASS values must be strings", 2)
				end
			end
			-- Pick first ASS value for interpolation
			local i = math.min(1 + math.floor(pct * (args.n-1)), args.n-1)
			-- Extract ASS value parts
			local success1, ass_r_a1, g1, b1, a1 = pcall(Yutils.ass.convert_coloralpha, args[i])
			local success2, ass_r_a2, g2, b2, a2 = pcall(Yutils.ass.convert_coloralpha, args[i+1])
			if not success1 or not success2 then
				error("invalid ASS value(s)", 2)
			end
			-- Process by ASS values type
			local min_pct, max_pct = (i-1) / (args.n-1), i / (args.n-1)
			local inner_pct = (pct - min_pct) / (max_pct - min_pct)
			if a1 and a2 then	-- Color + alpha
				return Yutils.ass.convert_coloralpha(ass_r_a1 + (ass_r_a2 - ass_r_a1) * inner_pct, g1 + (g2 - g1) * inner_pct, b1 + (b2 - b1) * inner_pct, a1 + (a2 - a1) * inner_pct)
			elseif b1 and not a1 and b2 and not a2 then	-- Color
				return Yutils.ass.convert_coloralpha(ass_r_a1 + (ass_r_a2 - ass_r_a1) * inner_pct, g1 + (g2 - g1) * inner_pct, b1 + (b2 - b1) * inner_pct)
			elseif not g1 and not g2 then	-- Alpha
				return Yutils.ass.convert_coloralpha(ass_r_a1 + (ass_r_a2 - ass_r_a1) * inner_pct)
			else
				error("ASS values must be the same type", 2)
			end
		end,
		-- Creates an ASS parser
		create_parser = function(ass_text)
			-- Check argument
			if ass_text ~= nil and type(ass_text) ~= "string" then
				error("optional string expected", 2)
			end
			-- Current section (for parsing validation)
			local section = ""
			-- ASS contents (just rendering relevant stuff)
			local meta = {wrap_style = 0, scaled_border_and_shadow = true, play_res_x = 0, play_res_y = 0}
			local styles = {}
			local dialogs = {n = 0}
			-- Create parser & getter object
			local obj = {
				parse_line = function(line)
					-- Check argument
					if type(line) ~= "string" then
						error("string expected", 2)
					end
					-- Parse (by) section
					if line:find("^%[.-%]$") then	-- Define section
						section = line:sub(2,-2)
						return true
					elseif section == "Script Info" then	-- Meta
						if line:find("^WrapStyle: %d$") then
							meta.wrap_style = tonumber(line:sub(12))
							return true
						elseif line:find("^ScaledBorderAndShadow: %l+$") then
							local value = line:sub(24)
							if value == "yes" or value == "no" then
								meta.scaled_border_and_shadow = value == "yes"
								return true
							end
						elseif line:find("^PlayResX: %d+$") then
							meta.play_res_x = tonumber(line:sub(11))
							return true
						elseif line:find("^PlayResY: %d+$") then
							meta.play_res_y = tonumber(line:sub(11))
							return true
						end
					elseif section == "V4+ Styles" then	-- Styles
						local name, fontname, fontsize, color1, color2, color3, color4,
								bold, italic, underline, strikeout, scale_x, scale_y, spacing, angle, border_style,
								outline, shadow, alignment, margin_l, margin_r, margin_v, encoding =
								line:match("^Style: (.-),(.-),(%d+),(&H%x%x%x%x%x%x%x%x),(&H%x%x%x%x%x%x%x%x),(&H%x%x%x%x%x%x%x%x),(&H%x%x%x%x%x%x%x%x),(%-?[01]),(%-?[01]),(%-?[01]),(%-?[01]),(%d+%.?%d*),(%d+%.?%d*),(%-?%d+%.?%d*),(%-?%d+%.?%d*),([13]),(%d+%.?%d*),(%d+%.?%d*),([1-9]),(%d+%.?%d*),(%d+%.?%d*),(%d+%.?%d*),(%d+)$")
						if encoding and tonumber(encoding) <= 255 then
							local style = {
								fontname = fontname,
								fontsize = tonumber(fontsize),
								bold = bold == "-1",
								italic = italic == "-1",
								underline = underline == "-1",
								strikeout = strikeout == "-1",
								scale_x = tonumber(scale_x),
								scale_y = tonumber(scale_y),
								spacing = tonumber(spacing),
								angle = tonumber(angle),
								border_style = border_style == "3",
								outline = tonumber(outline),
								shadow = tonumber(shadow),
								alignment = tonumber(alignment),
								margin_l = tonumber(margin_l),
								margin_r = tonumber(margin_r),
								margin_v = tonumber(margin_v),
								encoding = tonumber(encoding)
							}
							local r, g, b, a = Yutils.ass.convert_coloralpha(color1)
							style.color1 = Yutils.ass.convert_coloralpha(r, g, b)
							style.alpha1 = Yutils.ass.convert_coloralpha(a)
							r, g, b, a = Yutils.ass.convert_coloralpha(color2)
							style.color2 = Yutils.ass.convert_coloralpha(r, g, b)
							style.alpha2 = Yutils.ass.convert_coloralpha(a)
							r, g, b, a = Yutils.ass.convert_coloralpha(color3)
							style.color3 = Yutils.ass.convert_coloralpha(r, g, b)
							style.alpha3 = Yutils.ass.convert_coloralpha(a)
							r, g, b, a = Yutils.ass.convert_coloralpha(color4)
							style.color4 = Yutils.ass.convert_coloralpha(r, g, b)
							style.alpha4 = Yutils.ass.convert_coloralpha(a)
							styles[name] = style
							return true
						end
					elseif section == "Events" then	-- Dialogs
						local typ, layer, start_time, end_time, style, actor, margin_l, margin_r, margin_v, effect, text =
								line:match("^(.-): (%d+),(%d:%d%d:%d%d%.%d%d),(%d:%d%d:%d%d%.%d%d),(.-),(.-),(%d+%.?%d*),(%d+%.?%d*),(%d+%.?%d*),(.-),(.*)$")
						if text and (typ == "Dialogue" or typ == "Comment") then
							dialogs.n = dialogs.n + 1
							dialogs[dialogs.n] = {
								comment = typ == "Comment",
								layer = tonumber(layer),
								start_time = Yutils.ass.convert_time(start_time),
								end_time = Yutils.ass.convert_time(end_time),
								style = style,
								actor = actor,
								margin_l = tonumber(margin_l),
								margin_r = tonumber(margin_r),
								margin_v = tonumber(margin_v),
								effect = effect,
								text = text
							}
							return true
						end
					end
					-- Nothing parsed
					return false
				end,
				meta = function()
					return Yutils.table.copy(meta)
				end,
				styles = function()
					return Yutils.table.copy(styles)
				end,
				dialogs = function(extended)
					-- Check argument
					if extended ~= nil and type(extended) ~= "boolean" then
						error("optional extension flag expected")
					end
					-- Return extended dialogs
					if extended then
						-- Define text sizes getter
						local function text_sizes(text, style)
							local font = Yutils.decode.create_font(style.fontname, style.bold, style.italic, style.underline, style.strikeout, style.fontsize, style.scale_x/100, style.scale_y/100, style.spacing)
							local extents, metrics = font.text_extents(text), font.metrics()
							return extents.width, extents.height, metrics.ascent, metrics.descent, metrics.internal_leading, metrics.external_leading
						end
						if not pcall(text_sizes, "Test", {fontname="Arial",fontsize=10,bold=false,italic=false,underline=false,strikeout=false,scale_x=100,scale_y=100,spacing=0}) then	-- Fonts aren't supported/available?
							text_sizes = nil
						end
						-- Create dialogs copy & style storage
						local dialogs, dialog_styles, dialog, style_dialogs = Yutils.table.copy(dialogs), {}
						local space_width
						-- Process single dialogs
						for i=1, dialogs.n do
							dialog = dialogs[i]
							-- Append dialog to styles
							style_dialogs = dialog_styles[dialog.style]
							if not style_dialogs then
								style_dialogs = {n = 0}
								dialog_styles[dialog.style] = style_dialogs
							end
							style_dialogs.n = style_dialogs.n + 1
							style_dialogs[style_dialogs.n] = dialog
							-- Add dialog extra informations
							dialog.i = i
							dialog.duration = dialog.end_time - dialog.start_time
							dialog.mid_time = dialog.start_time + dialog.duration / 2
							dialog.styleref = styles[dialog.style]
							dialog.text_stripped = dialog.text:gsub("{.-}", "")
							-- Add dialog text sizes and positions (if possible)
							if text_sizes and dialog.styleref then
								dialog.width, dialog.height, dialog.ascent, dialog.descent, dialog.internal_leading, dialog.external_leading = text_sizes(dialog.text_stripped, dialog.styleref)
								if meta.play_res_x > 0 and meta.play_res_y > 0 then
									-- Horizontal position
									if (dialog.styleref.alignment-1) % 3 == 0 then
										dialog.left = dialog.margin_l ~= 0 and dialog.margin_l or dialog.styleref.margin_l
										dialog.center = dialog.left + dialog.width / 2
										dialog.right = dialog.left + dialog.width
										dialog.x = dialog.left
									elseif (dialog.styleref.alignment-2) % 3 == 0 then
										dialog.left = meta.play_res_x / 2 - dialog.width / 2
										dialog.center = dialog.left + dialog.width / 2
										dialog.right = dialog.left + dialog.width
										dialog.x = dialog.center
									else
										dialog.left = meta.play_res_x - (dialog.margin_r ~= 0 and dialog.margin_r or dialog.styleref.margin_r) - dialog.width
										dialog.center = dialog.left + dialog.width / 2
										dialog.right = dialog.left + dialog.width
										dialog.x = dialog.right
									end
									-- Vertical position
									if dialog.styleref.alignment > 6 then
										dialog.top = dialog.margin_v ~= 0 and dialog.margin_v or dialog.styleref.margin_v
										dialog.middle = dialog.top + dialog.height / 2
										dialog.bottom = dialog.top + dialog.height
										dialog.y = dialog.top
									elseif dialog.styleref.alignment > 3 then
										dialog.top = meta.play_res_y / 2 - dialog.height / 2
										dialog.middle = dialog.top + dialog.height / 2
										dialog.bottom = dialog.top + dialog.height
										dialog.y = dialog.middle
									else
										dialog.top = meta.play_res_y - (dialog.margin_v ~= 0 and dialog.margin_v or dialog.styleref.margin_v) - dialog.height
										dialog.middle = dialog.top + dialog.height / 2
										dialog.bottom = dialog.top + dialog.height
										dialog.y = dialog.bottom
									end
								end
								space_width = text_sizes(" ", dialog.styleref)
							end
							-- Add dialog text chunks
							dialog.text_chunked = {n = 0}
							do
								-- Has tags+text chunks?
								local chunk_start, chunk_end = dialog.text:find("{.-}")
								if not chunk_start then
									dialog.text_chunked = {n = 1, {tags = "", text = dialog.text}}
								else
									-- First chunk without tags
									if chunk_start ~= 1 then
										dialog.text_chunked.n = dialog.text_chunked.n + 1
										dialog.text_chunked[dialog.text_chunked.n] = {tags = "", text = dialog.text:sub(1, chunk_start-1)}
									end
									-- Chunks with tags
									local chunk2_start, chunk2_end
									repeat
										chunk2_start, chunk2_end = dialog.text:find("{.-}", chunk_end+1)
										dialog.text_chunked.n = dialog.text_chunked.n + 1
										dialog.text_chunked[dialog.text_chunked.n] = {tags = dialog.text:sub(chunk_start+1, chunk_end-1), text = dialog.text:sub(chunk_end+1, chunk2_start and chunk2_start-1 or -1)}
										chunk_start, chunk_end = chunk2_start, chunk2_end
									until not chunk_start
								end
							end
							-- Add dialog sylables
							dialog.syls = {n = 0}
							do
								local last_time, text_chunk, pretags, kdur, posttags, syl = 0
								-- Get sylables from text chunks
								for i=1, dialog.text_chunked.n do
									text_chunk = dialog.text_chunked[i]
									pretags, kdur, posttags = text_chunk.tags:match("(.-)\\[kK][of]?(%d+)(.*)")
									if posttags then	-- All tag groups have to contain karaoke times or everything is invalid (=no sylables there)
										syl = {
											i = dialog.syls.n + 1,
											start_time = last_time,
											mid_time = last_time + kdur * 10 / 2,
											end_time = last_time + kdur * 10,
											duration = kdur * 10,
											tags = pretags .. posttags
										}
										syl.prespace, syl.text, syl.postspace = text_chunk.text:match("(%s*)(%S*)(%s*)")
										syl.prespace, syl.postspace = syl.prespace:len(), syl.postspace:len()
										if text_sizes and dialog.styleref then
											syl.width, syl.height, syl.ascent, syl.descent, syl.internal_leading, syl.external_leading = text_sizes(syl.text, dialog.styleref)
										end
										last_time = syl.end_time
										dialog.syls.n = dialog.syls.n + 1
										dialog.syls[dialog.syls.n] = syl
									else
										dialog.syls = {n = 0}
										break
									end
								end
								-- Calculate sylable positions with all sylables data already available
								if dialog.syls.n > 0 and dialog.syls[1].width and meta.play_res_x > 0 and meta.play_res_y > 0 then
									if dialog.styleref.alignment > 6 or dialog.styleref.alignment < 4 then
										local cur_x = dialog.left
										for i=1, dialog.syls.n do
											syl = dialog.syls[i]
											-- Horizontal position
											cur_x = cur_x + syl.prespace * space_width
											syl.left = cur_x
											syl.center = syl.left + syl.width / 2
											syl.right = syl.left + syl.width
											syl.x = (dialog.styleref.alignment-1) % 3 == 0 and syl.left or
													(dialog.styleref.alignment-2) % 3 == 0 and syl.center or
													syl.right
											cur_x = cur_x + syl.width + syl.postspace * space_width
											-- Vertical position
											syl.top = dialog.top
											syl.middle = dialog.middle
											syl.bottom = dialog.bottom
											syl.y = dialog.y
										end
									else
										local max_width, sum_height = 0, 0
										for i=1, dialog.syls.n do
											syl = dialog.syls[i]
											max_width = math.max(max_width, syl.width)
											sum_height = sum_height + syl.height
										end
										local cur_y, x_fix = meta.play_res_y / 2 - sum_height / 2
										for i=1, dialog.syls.n do
											syl = dialog.syls[i]
											-- Horizontal position
											x_fix = (max_width - syl.width) / 2
											if dialog.styleref.alignment == 4 then
												syl.left = dialog.left + x_fix
												syl.center = syl.left + syl.width / 2
												syl.right = syl.left + syl.width
												syl.x = syl.left
											elseif dialog.styleref.alignment == 5 then
												syl.left = meta.play_res_x / 2 - syl.width / 2
												syl.center = syl.left + syl.width / 2
												syl.right = syl.left + syl.width
												syl.x = syl.center
											else -- dialog.styleref.alignment == 6
												syl.left = dialog.right - syl.width - x_fix
												syl.center = syl.left + syl.width / 2
												syl.right = syl.left + syl.width
												syl.x = syl.right
											end
											-- Vertical position
											syl.top = cur_y
											syl.middle = syl.top + syl.height / 2
											syl.bottom = syl.top + syl.height
											syl.y = syl.middle
											cur_y = cur_y + syl.height
										end
									end
								end
							end
							-- Add dialog words
							dialog.words = {n = 0}
							do
								local word
								for prespace, word_text, postspace in dialog.text_stripped:gmatch("(%s*)(%S+)(%s*)") do
									word = {
										i = dialog.words.n + 1,
										start_time = dialog.start_time,
										mid_time = dialog.mid_time,
										end_time = dialog.end_time,
										duration = dialog.duration,
										text = word_text,
										prespace = prespace:len(),
										postspace = postspace:len()
									}
									if text_sizes and dialog.styleref then
										word.width, word.height, word.ascent, word.descent, word.internal_leading, word.external_leading = text_sizes(word.text, dialog.styleref)
									end
									-- Add current word to dialog words
									dialog.words.n = dialog.words.n + 1
									dialog.words[dialog.words.n] = word
								end
								-- Calculate word positions with all words data already available
								if dialog.words.n > 0 and dialog.words[1].width and meta.play_res_x > 0 and meta.play_res_y > 0 then
									if dialog.styleref.alignment > 6 or dialog.styleref.alignment < 4 then
										local cur_x = dialog.left
										for i=1, dialog.words.n do
											word = dialog.words[i]
											-- Horizontal position
											cur_x = cur_x + word.prespace * space_width
											word.left = cur_x
											word.center = word.left + word.width / 2
											word.right = word.left + word.width
											word.x = (dialog.styleref.alignment-1) % 3 == 0 and word.left or
													(dialog.styleref.alignment-2) % 3 == 0 and word.center or
													word.right
											cur_x = cur_x + word.width + word.postspace * space_width
											-- Vertical position
											word.top = dialog.top
											word.middle = dialog.middle
											word.bottom = dialog.bottom
											word.y = dialog.y
										end
									else
										local max_width, sum_height = 0, 0
										for i=1, dialog.words.n do
											word = dialog.words[i]
											max_width = math.max(max_width, word.width)
											sum_height = sum_height + word.height
										end
										local cur_y, x_fix = meta.play_res_y / 2 - sum_height / 2
										for i=1, dialog.words.n do
											word = dialog.words[i]
											-- Horizontal position
											x_fix = (max_width - word.width) / 2
											if dialog.styleref.alignment == 4 then
												word.left = dialog.left + x_fix
												word.center = word.left + word.width / 2
												word.right = word.left + word.width
												word.x = word.left
											elseif dialog.styleref.alignment == 5 then
												word.left = meta.play_res_x / 2 - word.width / 2
												word.center = word.left + word.width / 2
												word.right = word.left + word.width
												word.x = word.center
											else -- dialog.styleref.alignment == 6
												word.left = dialog.right - word.width - x_fix
												word.center = word.left + word.width / 2
												word.right = word.left + word.width
												word.x = word.right
											end
											-- Vertical position
											word.top = cur_y
											word.middle = word.top + word.height / 2
											word.bottom = word.top + word.height
											word.y = word.middle
											cur_y = cur_y + word.height
										end
									end
								end
							end
							-- Add dialog characters
							dialog.chars = {n = 0}
							do
								local char, char_index, syl, word
								for _, char_text in Yutils.utf8.chars(dialog.text_stripped) do
									char = {
										i = dialog.chars.n + 1,
										start_time = dialog.start_time,
										mid_time = dialog.mid_time,
										end_time = dialog.end_time,
										duration = dialog.duration,
										text = char_text
									}
									char_index = 0
									for i=1, dialog.syls.n do
										syl = dialog.syls[i]
										for _ in Yutils.utf8.chars(string.format("%s%s%s", string.rep(" ", syl.prespace), syl.text, string.rep(" ", syl.postspace))) do
											char_index = char_index + 1
											if char_index == char.i then
												char.syl_i = syl.i
												char.start_time = syl.start_time
												char.mid_time = syl.mid_time
												char.end_time = syl.end_time
												char.duration = syl.duration
												goto syl_reference_found
											end
										end
									end
									::syl_reference_found::
									char_index = 0
									for i=1, dialog.words.n do
										word = dialog.words[i]
										for _ in Yutils.utf8.chars(string.format("%s%s%s", string.rep(" ", word.prespace), word.text, string.rep(" ", word.postspace))) do
											char_index = char_index + 1
											if char_index == char.i then
												char.word_i = word.i
												goto word_reference_found
											end
										end
									end
									::word_reference_found::
									if text_sizes and dialog.styleref then
										char.width, char.height, char.ascent, char.descent, char.internal_leading, char.external_leading = text_sizes(char.text, dialog.styleref)
									end
									dialog.chars.n = dialog.chars.n + 1
									dialog.chars[dialog.chars.n] = char
								end
								-- Calculate character positions with all characters data already available
								if dialog.chars.n > 0 and dialog.chars[1].width and meta.play_res_x > 0 and meta.play_res_y > 0 then
									if dialog.styleref.alignment > 6 or dialog.styleref.alignment < 4 then
										local cur_x = dialog.left
										for i=1, dialog.chars.n do
											char = dialog.chars[i]
											-- Horizontal position
											char.left = cur_x
											char.center = char.left + char.width / 2
											char.right = char.left + char.width
											char.x = (dialog.styleref.alignment-1) % 3 == 0 and char.left or
													(dialog.styleref.alignment-2) % 3 == 0 and char.center or
													char.right
											cur_x = cur_x + char.width
											-- Vertical position
											char.top = dialog.top
											char.middle = dialog.middle
											char.bottom = dialog.bottom
											char.y = dialog.y
										end
									else
										local max_width, sum_height = 0, 0
										for i=1, dialog.chars.n do
											char = dialog.chars[i]
											max_width = math.max(max_width, char.width)
											sum_height = sum_height + char.height
										end
										local cur_y, x_fix = meta.play_res_y / 2 - sum_height / 2
										for i=1, dialog.chars.n do
											char = dialog.chars[i]
											-- Horizontal position
											x_fix = (max_width - char.width) / 2
											if dialog.styleref.alignment == 4 then
												char.left = dialog.left + x_fix
												char.center = char.left + char.width / 2
												char.right = char.left + char.width
												char.x = char.left
											elseif dialog.styleref.alignment == 5 then
												char.left = meta.play_res_x / 2 - char.width / 2
												char.center = char.left + char.width / 2
												char.right = char.left + char.width
												char.x = char.center
											else -- dialog.styleref.alignment == 6
												char.left = dialog.right - char.width - x_fix
												char.center = char.left + char.width / 2
												char.right = char.left + char.width
												char.x = char.right
											end
											-- Vertical position
											char.top = cur_y
											char.middle = char.top + char.height / 2
											char.bottom = char.top + char.height
											char.y = char.middle
											cur_y = cur_y + char.height
										end
									end
								end
							end
						end
						-- Add durations between dialogs
						for _, dialogs in pairs(dialog_styles) do
							table.sort(dialogs, function(dialog1, dialog2) return dialog1.start_time <= dialog2.start_time end)
							for i=1, dialogs.n do
								dialog = dialogs[i]
								dialog.leadin = i == 1 and 1000.1 or dialog.start_time - dialogs[i-1].end_time
								dialog.leadout = i == dialogs.n and 1000.1 or dialogs[i+1].start_time - dialog.end_time
							end
						end
						-- Return modified copy
						return dialogs
					-- Return raw dialogs
					else
						return Yutils.table.copy(dialogs)
					end
				end
			}
			-- Parse ASS text
			if ass_text then
				for line in Yutils.algorithm.lines(ass_text) do
					obj.parse_line(line)	-- no errors possible
				end
			end
			-- Return object
			return obj
		end
	},
	-- Decoder sublibrary
	decode = {
		-- Creates BMP file reader
		create_bmp_reader = function(filename)
			-- Check argument
			if type(filename) ~= "string" then
				error("bitmap filename expected", 2)
			end
			-- Image decoders
			local function bmp_decode(filename)
				-- Open file handle
				local file = io.open(filename, "rb")
				if file then
					-- Read file header
					local header = file:read(14)
					if not header or #header ~= 14 then
						return "couldn't read file header"
					end
					-- Check BMP signature
					if header:sub(1,2) == "BM" then
						-- Read relevant file header fields
						local file_size, data_offset = bton(header:sub(3,6)), bton(header:sub(11,14))
						-- Read DIB header
						header = file:read(24)
						if not header or #header ~= 24 then
							return "couldn't read DIB header"
						end
						-- Read relevant DIB header fields
						local width, height, planes, bit_depth, compression, data_size = bton(header:sub(5,8)), bton(header:sub(9,12)), bton(header:sub(13,14)), bton(header:sub(15,16)), bton(header:sub(17,20)), bton(header:sub(21,24))
						-- Check read header data
						if width >= 2^31 then
							return "pixels in right-to-left order are not supported"
						elseif planes ~= 1 then
							return "planes must be 1"
						elseif bit_depth ~= 24 and bit_depth ~= 32 then
							return "bit depth must be 24 or 32"
						elseif compression ~= 0 then
							return "must be uncompressed RGB"
						elseif data_size == 0 then
							return "data size must not be zero"
						end
						-- Fix read header data
						if height >= 2^31 then
							height = height - 2^32
						end
						-- Read image data
						file:seek("set", data_offset)
						local data = file:read(data_size)
						if not data or #data ~= data_size then
							return "not enough data"
						end
						-- Calculate row size (round up to multiple of 4)
						local row_size = math.floor((bit_depth * width + 31) / 32) * 4
						-- All data read from file -> close handle (don't wait for GC)
						file:close()
						-- Return relevant bitmap informations
						return file_size, width, height, bit_depth, data_size, data, row_size
					end
				end
			end
			local function png_decode(filename)
				-- PNG decode library available?
				if libpng then
					-- Open file handle
					local file = io.open(filename, "rb")
					if file then
						-- Load file content & close no further needed file handle
						local file_content = file:read("*a")
						file:close()
						-- Get file size
						local file_size = #file_content
						-- Check PNG signature
						if file_size > ffi.C.PNG_SIGNATURE_SIZE and libpng.png_sig_cmp(ffi.cast("png_const_bytep", file_content), 0, ffi.C.PNG_SIGNATURE_SIZE) == 0 then
							-- Create PNG data structures & set error handlers
							local ppng, pinfo, err = ffi.new("png_structp[1]"), ffi.new("png_infop[1]")
							local function err_func(png, message)
								libpng.png_destroy_read_struct(ppng, pinfo, nil)
								err = ffi.string(message)
							end
							ppng[0] = libpng.png_create_read_struct(ffi.cast("char*", "1.5.14"), nil, err_func, err_func)
							if not ppng[0] then
								return "couldn't create png read structure"
							end
							pinfo[0] = libpng.png_create_info_struct(ppng[0])
							if not pinfo[0] then
								libpng.png_destroy_read_struct(ppng, nil, nil)
								return "couldn't create png info structure"
							end
							-- Decode file content to png structures
							local file_pos, file_content_bytes = 0, ffi.cast("png_bytep", file_content)
							libpng.png_set_read_fn(ppng[0], nil, function(png, output_bytes, required_bytes)
								if file_pos + required_bytes <= file_size then
									ffi.C.memcpy(output_bytes, file_content_bytes+file_pos, required_bytes)
									file_pos = file_pos + required_bytes
								end
							end)
							libpng.png_read_png(ppng[0], pinfo[0], ffi.C.PNG_TRANSFORM_STRIP_16 + ffi.C.PNG_TRANSFORM_PACKING + ffi.C.PNG_TRANSFORM_EXPAND + ffi.C.PNG_TRANSFORM_BGR, nil)
							if err then
								return err
							end
							libpng.png_set_interlace_handling(ppng[0])
							libpng.png_read_update_info(ppng[0], pinfo[0])
							if err then
								return err
							end
							-- Get header data
							local width, height, color_type, row_size = libpng.png_get_image_width(ppng[0], pinfo[0]), libpng.png_get_image_height(ppng[0], pinfo[0]), libpng.png_get_color_type(ppng[0], pinfo[0]), libpng.png_get_rowbytes(ppng[0], pinfo[0])
							local data_size, bit_depth = height * row_size
							if color_type == ffi.C.PNG_COLOR_TYPE_RGB then
								bit_depth = 24
							elseif color_type == ffi.C.PNG_COLOR_TYPE_RGBA then
								bit_depth = 32
							else
								libpng.png_destroy_read_struct(ppng, pinfo, nil)
								return "png data conversion to BGR(A) colorspace failed"
							end
							-- Get image data
							local rows = libpng.png_get_rows(ppng[0], pinfo[0])
							local data, data_n = {}, 0
							for i=0, height-1 do
								data_n = data_n + 1
								data[data_n] = ffi.string(rows[i], row_size)
							end
							data = table.concat(data)
							-- Clean up
							libpng.png_destroy_read_struct(ppng, pinfo, nil)
							-- Return relevant bitmap informations
							return file_size, width, height, bit_depth, data_size, data, row_size
						end
					end
				end
			end
			-- Try to decode file
			local bottom_up
			local file_size, width, height, bit_depth, data_size, data, row_size = bmp_decode(filename)
			if not file_size then
				file_size, width, height, bit_depth, data_size, data, row_size = png_decode(filename)
				if not file_size then
					error("couldn't decode file", 2)
				elseif type(file_size) == "string" then
					error(file_size, 2)
				else
					bottom_up = false
				end
			elseif type(file_size) == "string" then
				error(file_size, 2)
			else
				bottom_up = height >= 0
				height = math.abs(height)
			end
			-- Return bitmap object
			local obj
			obj = {
				file_size = function()
					return file_size
				end,
				width = function()
					return width
				end,
				height = function()
					return height
				end,
				bit_depth = function()
					return bit_depth
				end,
				data_size = function()
					return data_size
				end,
				row_size = function()
					return row_size
				end,
				bottom_up = function()
					return bottom_up
				end,
				data_raw = function()
					return data
				end,
				data_packed = function()
					local data_packed, data_packed_n = {}, 0
					local first_row, last_row, row_step
					if bottom_up then
						first_row, last_row, row_step = height-1, 0, -1
					else
						first_row, last_row, row_step = 0, height-1, 1
					end
					if bit_depth == 24 then
						local last_row_item, r, g, b = (width-1)*3
						for y=first_row, last_row, row_step do
							y = 1 + y * row_size
							for x=0, last_row_item, 3 do
								b, g, r = data:byte(y+x, y+x+2)
								data_packed_n = data_packed_n + 1
								data_packed[data_packed_n] = {
									r = r,
									g = g,
									b = b,
									a = 255
								}
							end
						end
					else	-- bit_depth == 32
						local last_row_item, r, g, b, a = (width-1)*4
						for y=first_row, last_row, row_step do
							y = 1 + y * row_size
							for x=0, last_row_item, 4 do
								b, g, r, a = data:byte(y+x, y+x+3)
								data_packed_n = data_packed_n + 1
								data_packed[data_packed_n] = {
									r = r,
									g = g,
									b = b,
									a = a
								}
							end
						end
					end
					return data_packed
				end,
				data_text = function()
					local data_pack, text, text_n = obj.data_packed(), {"{\\bord0\\shad0\\an7\\p1}"}, 1
					local x, y, off_x, chunk_size, color1, color2 = 0, 0, 0
					local i, n = 1, #data_pack
					while i <= n do
						if x == width then
							x = 0
							y = y + 1
							off_x = off_x - width
						end
						chunk_size, color1, text_n = 1, data_pack[i], text_n + 1
						if color1.a == 0 then
							for xx=x+1, width-1 do
								color2 = data_pack[i+(xx-x)]
								if not (color2 and color2.a == 0) then
									break
								end
								chunk_size = chunk_size + 1
							end
							text[text_n] = string.format("{}m %d %d l %d %d", off_x, y, off_x+chunk_size, y+1)
						else
							for xx=x+1, width-1 do
								color2 = data_pack[i+(xx-x)]
								if not (color2 and color1.r == color2.r and color1.g == color2.g and color1.b == color2.b and color1.a == color2.a) then
									break
								end
								chunk_size = chunk_size + 1
							end
							text[text_n] = string.format("{\\c&H%02X%02X%02X&\\1a&H%02X&}m %d %d l %d %d %d %d %d %d",
																	color1.b, color1.g, color1.r, 255-color1.a, off_x, y, off_x+chunk_size, y, off_x+chunk_size, y+1, off_x, y+1)
						end
						i, x = i + chunk_size, x + chunk_size
					end
					return table.concat(text)
				end
			}
			return obj
		end,
		-- Create WAV file reader
		create_wav_reader = function(filename)
			-- Check argument
			if type(filename) ~= "string" then
				error("audio filename expected", 2)
			end
			-- Open file handle
			local file = io.open(filename, "rb")
			if not file then
				error("couldn't open file", 2)
			end
			-- Read file header
			local header = file:read(12)
			if not header or #header ~= 12 then
				error("couldn't read file header", 2)
			-- Check WAVE signature
			elseif header:sub(1,4) ~= "RIFF" or header:sub(9,12) ~= "WAVE" then
				error("not a wave file", 2)
			end
			-- Data to save (+ read relevant file header field)
			local file_size, channels_number, sample_rate, byte_rate, block_align, bits_per_sample = bton(header:sub(5,8)) + 8	-- remaining + already read bytes
			local data_begin, data_end
			-- Read file chunks
			local chunk_type, chunk_size
			while true do
				-- Read single chunk
				chunk_type, chunk_size = file:read(4), file:read(4)
				if not chunk_size or #chunk_size ~= 4 then
					break
				end
				chunk_size = bton(chunk_size)
				-- Identify chunk type
				if chunk_type == "fmt " then
					-- Read format informations
					header = file:read(16)
					if chunk_size < 16 or not header or #header ~= 16 then
						error("format chunk corrupted", 2)
					elseif bton(header:sub(1,2)) ~= 1 then
						error("data must be in PCM format", 2)
					end
					channels_number, sample_rate, byte_rate, block_align, bits_per_sample = bton(header:sub(3,4)), bton(header:sub(5,8)), bton(header:sub(9,12)), bton(header:sub(13,14)), bton(header:sub(15,16))
					if bits_per_sample ~= 8 and bits_per_sample ~= 16 and bits_per_sample ~= 24 and bits_per_sample ~= 32 then
						error("bits per sample must be 8, 16, 24 or 32", 2)
					elseif channels_number == 0 or sample_rate == 0 or byte_rate == 0 or block_align == 0 then
						error("invalid format data", 2)
					end
					file:seek("cur", chunk_size-16)
				elseif chunk_type == "data" then
					-- Save samples reference
					data_begin = file:seek()
					data_end = data_begin + chunk_size
					file:seek("cur", chunk_size)
				else
					-- Skip chunk
					file:seek("cur", chunk_size)
				end
			end
			-- Check all needed data are read
			if not bits_per_sample or not data_end then
				error("format or data are missing", 2)
			end
			-- Calculate extra data
			local samples_per_channel = (data_end - data_begin) / block_align
			-- Set file pointer ready for data reading
			file:seek("set", data_begin)
			-- Return wave object
			local obj
			obj = {
				file_size = function()
					return file_size
				end,
				channels_number = function()
					return channels_number
				end,
				sample_rate = function()
					return sample_rate
				end,
				byte_rate = function()
					return byte_rate
				end,
				block_align = function()
					return block_align
				end,
				bits_per_sample = function()
					return bits_per_sample
				end,
				samples_per_channel = function()
					return samples_per_channel
				end,
				min_max_amplitude = function()
					local half_level = 2^bits_per_sample / 2
					return -half_level, half_level-1
				end,
				sample_from_ms = function(ms)
					if type(ms) ~= "number" or ms < 0 then
						error("positive number expected", 2)
					end
					return ms * 0.001 * sample_rate
				end,
				ms_from_sample = function(sample)
					if type(sample) ~= "number" or sample < 0 then
						error("positive number expected", 2)
					end
					return sample / sample_rate * 1000
				end,
				position = function(pos)
					if pos ~= nil and (type(pos) ~= "number" or pos < 0) then
						error("optional positive number expected", 2)
					elseif pos then
						file:seek("set", data_begin + pos * block_align)
					end
					return (file:seek() - data_begin) / block_align
				end,
				samples_interlaced = function(n)
					if type(n) ~= "number" or math.floor(n) < 1 then
						error("positive number greater-equal one expected", 2)
					end
					local output, bytes = {n = 0}, file:read(math.floor(n) * block_align)
					if bytes then
						local bytes_per_sample, sample = bits_per_sample / 8
						local max_amplitude, amplitude_fix = ({127, 32767, 8388607, 2147483647})[bytes_per_sample], ({256, 65536, 16777216, 4294967296})[bytes_per_sample]
						for i=1, #bytes, bytes_per_sample do
							sample = bton(bytes:sub(i,i+bytes_per_sample-1))
							output.n = output.n + 1
							output[output.n] = sample > max_amplitude and sample - amplitude_fix or sample
						end
					end
					return output
				end,
				samples = function(n)
					local success, samples = pcall(obj.samples_interlaced, n)
					if not success then
						error(samples, 2)
					end
					local output, channel_samples = {n = channels_number}
					for c=1, output.n do
						channel_samples = {n = math.floor(samples.n / channels_number)}
						for s=1, channel_samples.n do
							channel_samples[s] = samples[c + (s-1) * channels_number]
						end
						output[c] = channel_samples
					end
					return output
				end
			}
			return obj
		end,
		create_frequency_analyzer = function(samples, sample_rate)
			-- Check arguments
			if type(samples) ~= "table" or type(sample_rate) ~= "number" or sample_rate < 2 or sample_rate % 2 ~= 0 then
				error("samples table and sample rate expected", 2)
			end
			local samples_n = #samples
			if samples_n < 2 then
				error("not enough samples", 2)
			end
			local sample
			for i=1, samples_n do
				sample = samples[i]
				if type(sample) ~= "number" then
					error("samples have to be numbers", 2)
				elseif sample < -1 or sample > 1 then
					error("samples have to be in range -1 <> 1", 2)
				end
			end
			-- Fix samples number to power of 2 for further processing
			samples_n = 2^math.floor(math.log(samples_n, 2))
			-- Complex numbers
			local complex_t
			do
				local complex = {}
				complex_t = function(r, i)
					return setmetatable({r = r, i = i}, complex)
				end
				local function tocomplex(a, b)
					if getmetatable(a) ~= complex then return {r = a, i = 0}, b
					elseif getmetatable(b) ~= complex then return a, {r = b, i = 0}
					else return a, b end
				end
				complex.__add = function(a, b)
					local c1, c2 = tocomplex(a, b)
					return complex_t(c1.r + c2.r, c1.i + c2.i)
				end
				complex.__sub = function(a, b)
					local c1, c2 = tocomplex(a, b)
					return complex_t(c1.r - c2.r, c1.i - c2.i)
				end
				complex.__mul = function(a, b)
					local c1, c2 = tocomplex(a, b)
					return complex_t(c1.r * c2.r - c1.i * c2.i, c1.r * c2.i + c1.i * c2.r)
				end
			end
			local function polar(theta)
				return complex_t(math.cos(theta), math.sin(theta))
			end
			local function magnitude(c)
				return math.sqrt(c.r^2 + c.i^2)
			end
			-- Fast Fourier Transformation
			local function fft(x)
				-- Check recursion break
				local N = x.n
				if N > 1 then
					-- Divide
					local even, odd = {n = 0}, {n = 0}
					for i=1, N, 2 do
						even.n = even.n + 1
						even[even.n] = x[i]
					end
					for i=2, N, 2 do
						odd.n = odd.n + 1
						odd[odd.n] = x[i]
					end
					-- Conquer
					fft(even)
					fft(odd)
					--Combine
					local t
					for k = 1, N/2 do
						t = polar(-2 * math.pi * (k-1) / N) * odd[k]
						x[k] = even[k] + t
						x[k+N/2] = even[k] - t
					end
				end
			end
			-- Samples to complex numbers
			local data = {n = samples_n}
			for i = 1, data.n do
				data[i] = complex_t(samples[i], 0)
			end
			-- Process FFT
			fft(data)
			-- Complex numbers to frequencies domain data
			for i = 1, data.n do
				data[i] = magnitude(data[i])
			end
			-- Extract frequencies weights
			local frequencies, frequency_sum, sample_rate_half = {n = data.n / 2}, 0, sample_rate / 2
			for i=1, frequencies.n do
				frequency_sum = frequency_sum + data[i]
			end
			if frequency_sum == 0 then
				frequencies[1] = {freq = 0, weight = 1}
				for i=2, frequencies.n do
					frequencies[i] = {freq = (i-1) / (frequencies.n-1) * sample_rate_half, weight = 0}
				end
			else
				for i=1, frequencies.n do
					frequencies[i] = {freq = (i-1) / (frequencies.n-1) * sample_rate_half, weight = data[i] / frequency_sum}
				end
			end
			-- Return frequencies object
			return {
				frequencies = function()
					return Yutils.table.copy(frequencies)
				end,
				frequency_weight = function(freq)
					if type(freq) ~= "number" or freq < 0 or freq > sample_rate_half then
						error("valid frequency expected", 2)
					end
					local frequency
					for i=1, frequencies.n do
						frequency = frequencies[i]
						if frequency.freq == freq then
							return frequency.weight
						elseif frequency.freq > freq then
							local frequency_last = frequencies[i-1]
							return (freq - frequency_last.freq) / (frequency.freq - frequency_last.freq) * (frequency.weight - frequency_last.weight) + frequency_last.weight
						end
					end
				end,
				frequency_range_weight = function(freq_min, freq_max)
					if type(freq_min) ~= "number" or freq_min < 0 or freq_min > sample_rate_half or
						type(freq_max) ~= "number" or freq_max < 0 or freq_max > sample_rate_half or
						freq_min > freq_max then
						error("valid frequencies expected", 2)
					end
					local weight_sum, frequency = 0
					for i=1, frequencies.n do
						frequency = frequencies[i]
						if frequency.freq >= freq_min then
							if frequency.freq <= freq_max then
								weight_sum = weight_sum + frequency.weight
							else
								break
							end
						end
					end
					return weight_sum
				end
			}
		end,
		-- Creates font
		create_font = function(family, bold, italic, underline, strikeout, size, xscale, yscale, hspace)
			-- Check arguments
			if type(family) ~= "string" or type(bold) ~= "boolean" or type(italic) ~= "boolean" or type(underline) ~= "boolean" or type(strikeout) ~= "boolean" or type(size) ~= "number" or size <= 0 or
				(xscale ~= nil and type(xscale) ~= "number") or (yscale ~= nil and type(yscale) ~= "number") or (hspace ~= nil and type(hspace) ~= "number") then
				error("expected family, bold, italic, underline, strikeout, size and optional horizontal & vertical scale and intercharacter space", 2)
			end
			-- Set optional arguments (if not already)
			if not xscale then
				xscale = 1
			end
			if not yscale then
				yscale = 1
			end
			if not hspace then
				hspace = 0
			end
			-- Font scale values for increased size & later downscaling to produce floating point coordinates
			local upscale = FONT_PRECISION
			local downscale = 1 / upscale
			-- Body by operation system
			if ffi.os == "Windows" then
				-- Create device context and set light resources deleter
				local resources_deleter
				local dc = ffi.gc(ffi.C.CreateCompatibleDC(nil), function() resources_deleter() end)
				-- Set context coordinates mapping mode
				ffi.C.SetMapMode(dc, ffi.C.MM_TEXT)
				-- Set context backgrounds to transparent
				ffi.C.SetBkMode(dc, ffi.C.TRANSPARENT)
				-- Convert family from utf8 to utf16
				family = utf8_to_utf16(family)
				if ffi.C.wcslen(family) > 31 then
					error("family name to long", 2)
				end
				-- Create font handle
				local font = ffi.C.CreateFontW(
					size * upscale,	-- nHeight
					0,	-- nWidth
					0,	-- nEscapement
					0,	-- nOrientation
					bold and ffi.C.FW_BOLD or ffi.C.FW_NORMAL,	-- fnWeight
					italic and 1 or 0,	-- fdwItalic
					underline and 1 or 0,	--fdwUnderline
					strikeout and 1 or 0,	-- fdwStrikeOut
					ffi.C.DEFAULT_CHARSET,	-- fdwCharSet
					ffi.C.OUT_TT_PRECIS,	-- fdwOutputPrecision
					ffi.C.CLIP_DEFAULT_PRECIS,	-- fdwClipPrecision
					ffi.C.ANTIALIASED_QUALITY,	-- fdwQuality
					ffi.C.DEFAULT_PITCH + ffi.C.FF_DONTCARE,	-- fdwPitchAndFamily
					family
				)
				-- Set new font to device context
				local old_font = ffi.C.SelectObject(dc, font)
				-- Define light resources deleter
				resources_deleter = function()
					ffi.C.SelectObject(dc, old_font)
					ffi.C.DeleteObject(font)
					ffi.C.DeleteDC(dc)
				end
				-- Return font object
				return {
					-- Get font metrics
					metrics = function()
						-- Get font metrics from device context
						local metrics = ffi.new("TEXTMETRICW[1]")
						ffi.C.GetTextMetricsW(dc, metrics)
						return {
							height = metrics[0].tmHeight * downscale * yscale,
							ascent = metrics[0].tmAscent * downscale * yscale,
							descent = metrics[0].tmDescent * downscale * yscale,
							internal_leading = metrics[0].tmInternalLeading * downscale * yscale,
							external_leading = metrics[0].tmExternalLeading * downscale * yscale
						}
					end,
					-- Get text extents
					text_extents = function(text)
						-- Check argument
						if type(text) ~= "string" then
							error("text expected", 2)
						end
						-- Get utf16 text
						text = utf8_to_utf16(text)
						local text_len = ffi.C.wcslen(text)
						-- Get text extents with this font
						local size = ffi.new("SIZE[1]")
						ffi.C.GetTextExtentPoint32W(dc, text, text_len, size)
						return {
							width = (size[0].cx * downscale + hspace * text_len) * xscale,
							height = size[0].cy * downscale * yscale
						}
					end,
					-- Converts text to ASS shape
					text_to_shape = function(text)
						-- Check argument
						if type(text) ~= "string" then
							error("text expected", 2)
						end
						-- Initialize shape as table
						local shape, shape_n = {}, 0
						-- Get utf16 text
						text = utf8_to_utf16(text)
						local text_len = ffi.C.wcslen(text)
						-- Add path to device context
						if text_len > 8192 then
							error("text too long", 2)
						end
						local char_widths
						if hspace ~= 0 then
							char_widths = ffi.new("INT[?]", text_len)
							local size, space = ffi.new("SIZE[1]"), hspace * upscale
							for i=0, text_len-1 do
								ffi.C.GetTextExtentPoint32W(dc, text+i, 1, size)
								char_widths[i] = size[0].cx + space
							end
						end
						ffi.C.BeginPath(dc)
						ffi.C.ExtTextOutW(dc, 0, 0, 0x0, nil, text, text_len, char_widths)
						ffi.C.EndPath(dc)
						-- Get path data
						local points_n = ffi.C.GetPath(dc, nil, nil, 0)
						if points_n > 0 then
							local points, types = ffi.new("POINT[?]", points_n), ffi.new("BYTE[?]", points_n)
							ffi.C.GetPath(dc, points, types, points_n)
							-- Convert points to shape
							local i, last_type, cur_type, cur_point = 0
							while i < points_n do
								cur_type, cur_point = types[i], points[i]
								if cur_type == ffi.C.PT_MOVETO then
									if last_type ~= ffi.C.PT_MOVETO then
										shape_n = shape_n + 1
										shape[shape_n] = "m"
										last_type = cur_type
									end
									shape[shape_n+1] = Yutils.math.round(cur_point.x * downscale * xscale, FP_PRECISION)
									shape[shape_n+2] = Yutils.math.round(cur_point.y * downscale * yscale, FP_PRECISION)
									shape_n = shape_n + 2
									i = i + 1
								elseif cur_type == ffi.C.PT_LINETO or cur_type == (ffi.C.PT_LINETO + ffi.C.PT_CLOSEFIGURE) then
									if last_type ~= ffi.C.PT_LINETO then
										shape_n = shape_n + 1
										shape[shape_n] = "l"
										last_type = cur_type
									end
									shape[shape_n+1] = Yutils.math.round(cur_point.x * downscale * xscale, FP_PRECISION)
									shape[shape_n+2] = Yutils.math.round(cur_point.y * downscale * yscale, FP_PRECISION)
									shape_n = shape_n + 2
									i = i + 1
								elseif cur_type == ffi.C.PT_BEZIERTO or cur_type == (ffi.C.PT_BEZIERTO + ffi.C.PT_CLOSEFIGURE) then
									if last_type ~= ffi.C.PT_BEZIERTO then
										shape_n = shape_n + 1
										shape[shape_n] = "b"
										last_type = cur_type
									end
									shape[shape_n+1] = Yutils.math.round(cur_point.x * downscale * xscale, FP_PRECISION)
									shape[shape_n+2] = Yutils.math.round(cur_point.y * downscale * yscale, FP_PRECISION)
									shape[shape_n+3] = Yutils.math.round(points[i+1].x * downscale * xscale, FP_PRECISION)
									shape[shape_n+4] = Yutils.math.round(points[i+1].y * downscale * yscale, FP_PRECISION)
									shape[shape_n+5] = Yutils.math.round(points[i+2].x * downscale * xscale, FP_PRECISION)
									shape[shape_n+6] = Yutils.math.round(points[i+2].y * downscale * yscale, FP_PRECISION)
									shape_n = shape_n + 6
									i = i + 3
								else	-- invalid type (should never happen, but let us be safe)
									i = i + 1
								end
								if cur_type % 2 == 1 then	-- odd = PT_CLOSEFIGURE
									shape_n = shape_n + 1
									shape[shape_n] = "c"
								end
							end
						end
						-- Clear device context path
						ffi.C.AbortPath(dc)
						-- Return shape as string
						return table.concat(shape, " ")
					end
				}
			else	-- Unix
				-- Check whether or not the pangocairo library was loaded
				if not pangocairo then
					error("pangocairo library couldn't be loaded", 2)
				end
				-- Create surface, context & layout
				local surface = pangocairo.cairo_image_surface_create(ffi.C.CAIRO_FORMAT_A8, 1, 1)
				local context = pangocairo.cairo_create(surface)
				local layout
				layout = ffi.gc(pangocairo.pango_cairo_create_layout(context), function()
					pangocairo.g_object_unref(layout)
					pangocairo.cairo_destroy(context)
					pangocairo.cairo_surface_destroy(surface)
				end)
				-- Set font to layout
				local font_desc = ffi.gc(pangocairo.pango_font_description_new(), pangocairo.pango_font_description_free)
				pangocairo.pango_font_description_set_family(font_desc, family)
				pangocairo.pango_font_description_set_weight(font_desc, bold and ffi.C.PANGO_WEIGHT_BOLD or ffi.C.PANGO_WEIGHT_NORMAL)
				pangocairo.pango_font_description_set_style(font_desc, italic and ffi.C.PANGO_STYLE_ITALIC or ffi.C.PANGO_STYLE_NORMAL)
				pangocairo.pango_font_description_set_absolute_size(font_desc, size * ffi.C.PANGO_SCALE * upscale)
				pangocairo.pango_layout_set_font_description(layout, font_desc)
				local attr = ffi.gc(pangocairo.pango_attr_list_new(), pangocairo.pango_attr_list_unref)
				pangocairo.pango_attr_list_insert(attr, pangocairo.pango_attr_underline_new(underline and ffi.C.PANGO_UNDERLINE_SINGLE or ffi.C.PANGO_UNDERLINE_NONE))
				pangocairo.pango_attr_list_insert(attr, pangocairo.pango_attr_strikethrough_new(strikeout))
				pangocairo.pango_attr_list_insert(attr, pangocairo.pango_attr_letter_spacing_new(hspace * ffi.C.PANGO_SCALE * upscale))
				pangocairo.pango_layout_set_attributes(layout, attr)
				-- Scale factor for resulting font data
				local fonthack_scale
				if LIBASS_FONTHACK then
					local metrics = ffi.gc(pangocairo.pango_context_get_metrics(pangocairo.pango_layout_get_context(layout), pangocairo.pango_layout_get_font_description(layout), nil), pangocairo.pango_font_metrics_unref)
					fonthack_scale = size / ((pangocairo.pango_font_metrics_get_ascent(metrics) + pangocairo.pango_font_metrics_get_descent(metrics)) / ffi.C.PANGO_SCALE * downscale)
				else
					fonthack_scale = 1
				end
				-- Return font object
				return {
					-- Get font metrics
					metrics = function()
						local metrics = ffi.gc(pangocairo.pango_context_get_metrics(pangocairo.pango_layout_get_context(layout), pangocairo.pango_layout_get_font_description(layout), nil), pangocairo.pango_font_metrics_unref)
						local ascent, descent = pangocairo.pango_font_metrics_get_ascent(metrics) / ffi.C.PANGO_SCALE * downscale,
												pangocairo.pango_font_metrics_get_descent(metrics) / ffi.C.PANGO_SCALE * downscale
						return {
							height = (ascent + descent) * yscale * fonthack_scale,
							ascent = ascent * yscale * fonthack_scale,
							descent = descent * yscale * fonthack_scale,
							internal_leading = 0,
							external_leading = pangocairo.pango_layout_get_spacing(layout) / ffi.C.PANGO_SCALE * downscale * yscale * fonthack_scale
						}
					end,
					-- Get text extents
					text_extents = function(text)
						-- Check argument
						if type(text) ~= "string" then
							error("text expected", 2)
						end
						-- Set text to layout
						pangocairo.pango_layout_set_text(layout, text, -1)
						-- Get text extents with this font
						local rect = ffi.new("PangoRectangle[1]")
						pangocairo.pango_layout_get_pixel_extents(layout, nil, rect)
						return {
							width = rect[0].width * downscale * xscale * fonthack_scale,
							height = rect[0].height * downscale * yscale * fonthack_scale
						}
					end,
					-- Converts text to ASS shape
					text_to_shape = function(text)
						-- Check argument
						if type(text) ~= "string" then
							error("text expected", 2)
						end
						-- Set text path to layout
						pangocairo.cairo_save(context)
						pangocairo.cairo_scale(context, downscale * xscale * fonthack_scale, downscale * yscale * fonthack_scale)
						pangocairo.pango_layout_set_text(layout, text, -1)
						pangocairo.pango_cairo_layout_path(context, layout)
						pangocairo.cairo_restore(context)
						-- Initialize shape as table
						local shape, shape_n = {}, 0
						-- Convert path to shape
						local path = ffi.gc(pangocairo.cairo_copy_path(context), pangocairo.cairo_path_destroy)
						if(path[0].status == ffi.C.CAIRO_STATUS_SUCCESS) then
							local i, cur_type, last_type = 0
							while(i < path[0].num_data) do
								cur_type = path[0].data[i].header.type
								if cur_type == ffi.C.CAIRO_PATH_MOVE_TO then
									if cur_type ~= last_type then
										shape_n = shape_n + 1
										shape[shape_n] = "m"
									end
									shape[shape_n+1] = Yutils.math.round(path[0].data[i+1].point.x, FP_PRECISION)
									shape[shape_n+2] = Yutils.math.round(path[0].data[i+1].point.y, FP_PRECISION)
									shape_n = shape_n + 2
								elseif cur_type == ffi.C.CAIRO_PATH_LINE_TO then
									if cur_type ~= last_type then
										shape_n = shape_n + 1
										shape[shape_n] = "l"
									end
									shape[shape_n+1] = Yutils.math.round(path[0].data[i+1].point.x, FP_PRECISION)
									shape[shape_n+2] = Yutils.math.round(path[0].data[i+1].point.y, FP_PRECISION)
									shape_n = shape_n + 2
								elseif cur_type == ffi.C.CAIRO_PATH_CURVE_TO then
									if cur_type ~= last_type then
										shape_n = shape_n + 1
										shape[shape_n] = "b"
									end
									shape[shape_n+1] = Yutils.math.round(path[0].data[i+1].point.x, FP_PRECISION)
									shape[shape_n+2] = Yutils.math.round(path[0].data[i+1].point.y, FP_PRECISION)
									shape[shape_n+3] = Yutils.math.round(path[0].data[i+2].point.x, FP_PRECISION)
									shape[shape_n+4] = Yutils.math.round(path[0].data[i+2].point.y, FP_PRECISION)
									shape[shape_n+5] = Yutils.math.round(path[0].data[i+3].point.x, FP_PRECISION)
									shape[shape_n+6] = Yutils.math.round(path[0].data[i+3].point.y, FP_PRECISION)
									shape_n = shape_n + 6
								elseif cur_type == ffi.C.CAIRO_PATH_CLOSE_PATH then
									if cur_type ~= last_type then
										shape_n = shape_n + 1
										shape[shape_n] = "c"
									end
								end
								last_type = cur_type
								i = i + path[0].data[i].header.length
							end
						end
						pangocairo.cairo_new_path(context)
						return table.concat(shape, " ")
					end
				}
			end
		end,
		-- Lists available system fonts
		list_fonts = function(with_filenames)
			-- Check argument
			if with_filenames ~= nil and type(with_filenames) ~= "boolean" then
				error("optional boolean expected", 2)
			end
			-- Output fonts buffer
			local fonts = {n = 0}
			-- Body by operation system
			if ffi.os == "Windows" then
				-- Enumerate font families (of all charsets)
				local plogfont = ffi.new("LOGFONTW[1]")
				plogfont[0].lfCharSet = ffi.C.DEFAULT_CHARSET
				plogfont[0].lfFaceName[0] = 0	-- Empty string
				plogfont[0].lfPitchAndFamily = ffi.C.DEFAULT_PITCH + ffi.C.FF_DONTCARE
				local fontname, style, font
				ffi.C.EnumFontFamiliesExW(ffi.gc(ffi.C.CreateCompatibleDC(nil), ffi.C.DeleteDC), plogfont, function(penumlogfont, _, fonttype, _)
					-- Skip different font charsets
					fontname, style = utf16_to_utf8(penumlogfont[0].elfLogFont.lfFaceName), utf16_to_utf8(penumlogfont[0].elfStyle)
					for i=1, fonts.n do
						font = fonts[i]
						if font.name == fontname and font.style == style then
							goto win_font_found
						end
					end
					-- Add font entry
					fonts.n = fonts.n + 1
					fonts[fonts.n] = {
						name = fontname,
						longname = utf16_to_utf8(penumlogfont[0].elfFullName),
						style = style,
						type = fonttype == ffi.C.FONTTYPE_RASTER and "Raster" or fonttype == ffi.C.FONTTYPE_DEVICE and "Device" or fonttype == ffi.C.FONTTYPE_TRUETYPE and "TrueType" or "Unknown",
					}
					::win_font_found::
					-- Continue enumeration (till end)
					return 1
				end, 0, 0)
				-- Files to fonts?
				if with_filenames then
					-- Adds filename to fitting font
					local function file_to_font(fontname, fontfile)
						for i=1, fonts.n do
							font = fonts[i]
							if fontname == font.name:gsub("^@", "", 1) or fontname == string.format("%s %s", font.name:gsub("^@", "", 1), font.style) or fontname == font.longname:gsub("^@", "", 1) then
								font.file = fontfile
							end
						end
					end
					-- Search registry for font files
					local pregkey, fontfile = ffi.new("HKEY[1]")
					if advapi.RegOpenKeyExA(ffi.cast("HKEY", ffi.C.HKEY_LOCAL_MACHINE), "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Fonts", 0, ffi.C.KEY_READ, pregkey) == ffi.C.ERROR_SUCCESS then
						local regkey = ffi.gc(pregkey[0], advapi.RegCloseKey)
						local value_index, value_name, pvalue_name_size, value_data, pvalue_data_size = 0, ffi.new("wchar_t[16383]"), ffi.new("DWORD[1]"), ffi.new("BYTE[65536]"), ffi.new("DWORD[1]")
						while true do
							pvalue_name_size[0], pvalue_data_size[0] = ffi.sizeof(value_name) / ffi.sizeof("wchar_t"), ffi.sizeof(value_data)
							if advapi.RegEnumValueW(regkey, value_index, value_name, pvalue_name_size, nil, nil, value_data, pvalue_data_size) ~= ffi.C.ERROR_SUCCESS then
								break
							else
								value_index = value_index + 1
							end
							fontname = utf16_to_utf8(value_name):gsub("(.*) %(.-%)$", "%1", 1)
							fontfile = utf16_to_utf8(ffi.cast("wchar_t*", value_data))
							file_to_font(fontname, fontfile)
							if fontname:find(" & ") then
								for fontname in fontname:gmatch("(.-) & ") do
									file_to_font(fontname, fontfile)
								end
								file_to_font(fontname:match(".* & (.-)$"), fontfile)
							end
						end
					end
				end
			else	-- Unix
				-- Check whether or not the fontconfig library was loaded
				if not fontconfig then
					error("fontconfig library couldn't be loaded", 2)
				end
				-- Get fonts list from fontconfig
				local fontset = ffi.gc(fontconfig.FcFontList(fontconfig.FcInitLoadConfigAndFonts(),
															ffi.gc(fontconfig.FcPatternCreate(), fontconfig.FcPatternDestroy),
															ffi.gc(fontconfig.FcObjectSetBuild("family", "fullname", "style", "outline", with_filenames and "file" or nil, nil), fontconfig.FcObjectSetDestroy)),
										fontconfig.FcFontSetDestroy)
				-- Enumerate fonts
				local font, family, fullname, style, outline, file
				local cstr, cbool = ffi.new("FcChar8*[1]"), ffi.new("FcBool[1]")
				for i=0, fontset[0].nfont-1 do
					-- Get font informations
					font = fontset[0].fonts[i]
					family, fullname, style, outline, file = nil
					if fontconfig.FcPatternGetString(font, "family", 0, cstr) == ffi.C.FcResultMatch then
						family = ffi.string(cstr[0])
					end
					if fontconfig.FcPatternGetString(font, "fullname", 0, cstr) == ffi.C.FcResultMatch then
						fullname = ffi.string(cstr[0])
					end
					if fontconfig.FcPatternGetString(font, "style", 0, cstr) == ffi.C.FcResultMatch then
						style = ffi.string(cstr[0])
					end
					if fontconfig.FcPatternGetBool(font, "outline", 0, cbool) == ffi.C.FcResultMatch then
						outline = cbool[0]
					end
					if fontconfig.FcPatternGetString(font, "file", 0, cstr) == ffi.C.FcResultMatch then
						file = ffi.string(cstr[0])
					end
					-- Add font entry
					if family and fullname and style and outline then
						fonts.n = fonts.n + 1
						fonts[fonts.n] = {
							name = family,
							longname = fullname,
							style = style,
							type = outline == 0 and "Raster" or "Outline",
							file = file
						}
					end
				end
			end
			-- Order fonts by name & style
			table.sort(fonts, function(font1, font2)
				if font1.name == font2.name then
					return font1.style < font2.style
				else
					return font1.name < font2.name
				end
			end)
			-- Return collected fonts
			return fonts
		end
	}
}

-- Put library in global scope (if first script argument is true)
if ({...})[1] then
	_G.Yutils = Yutils
end

-- Return library to script loader
return Yutils