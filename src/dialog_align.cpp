// Copyright (c) 2019, Charlie Jiang
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
//   * Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//   * Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//   * Neither the name of the Aegisub Group nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Aegisub Project http://www.aegisub.org/

#include "ass_dialogue.h"
#include "ass_file.h"
#include "compat.h"
#include "dialog_manager.h"
#include "format.h"
#include "include/aegisub/context.h"
#include "video_frame.h"
#include "libresrc/libresrc.h"
#include "options.h"
#include "project.h"
#include "selection_controller.h"
#include "video_controller.h"
#include "async_video_provider.h"
#include "colour_button.h"
#include "image_position_picker.h"

#include <cmath>

#include <libaegisub/ass/time.h>
#include <libaegisub/vfr.h>

#include <wx/dialog.h>
#include <wx/sizer.h>
#include <wx/textctrl.h>
#if BOOST_VERSION >= 106900
#include <boost/gil.hpp>
#else
#include <boost/gil/gil_all.hpp>
#endif

namespace {
	class DialogAlignToVideo final : public wxDialog {
		agi::Context* context;
		AsyncVideoProvider* provider;

		wxImage preview_image;
		VideoFrame current_frame;
		int current_n_frame;

		ImagePositionPicker* preview_frame;
		ColourButton* selected_color;
		wxTextCtrl* selected_x;
		wxTextCtrl* selected_y;
		wxTextCtrl* selected_tolerance;

		void update_from_textbox();
		void update_from_textbox(wxCommandEvent&);

		bool check_exists(int pos, int x, int y, int* lrud, double* orig, unsigned char tolerance);
		void process(wxCommandEvent&);
	public:
		DialogAlignToVideo(agi::Context* context);
		~DialogAlignToVideo();
	};

	DialogAlignToVideo::DialogAlignToVideo(agi::Context* context)
		: wxDialog(context->parent, -1, _("Align subtitle to video by key point"), wxDefaultPosition, wxDefaultSize, wxDEFAULT_DIALOG_STYLE | wxMAXIMIZE_BOX | wxRESIZE_BORDER)
		, context(context), provider(context->project->VideoProvider())
	{
		auto add_with_label = [&](wxSizer * sizer, wxString const& label, wxWindow * ctrl) {
			sizer->Add(new wxStaticText(this, -1, label), 0, wxLEFT | wxRIGHT | wxCENTER, 3);
			sizer->Add(ctrl, 1, wxLEFT);
		};

		auto tolerance = OPT_GET("Tool/Align to Video/Tolerance")->GetInt();
		auto maximized = OPT_GET("Tool/Align to Video/Maximized")->GetBool();

		current_n_frame = context->videoController->GetFrameN();
		current_frame = *context->project->VideoProvider()->GetFrame(current_n_frame, 0, true);
		preview_image = GetImage(current_frame);

		preview_frame = new ImagePositionPicker(this, preview_image, [&](int x, int y, unsigned char r, unsigned char g, unsigned char b) -> void {
			selected_x->ChangeValue(wxString::Format(wxT("%i"), x));
			selected_y->ChangeValue(wxString::Format(wxT("%i"), y));

			selected_color->SetColor(agi::Color(r, g, b));
			});
		selected_color = new ColourButton(this, wxSize(55, 16), true, agi::Color("FFFFFF"));
		selected_color->SetToolTip(_("The key color to be followed."));
		selected_x = new wxTextCtrl(this, -1, "0");
		selected_x->SetToolTip(_("The x coord of the key point."));
		selected_y = new wxTextCtrl(this, -1, "0");
		selected_y->SetToolTip(_("The y coord of the key point."));
		selected_tolerance = new wxTextCtrl(this, -1, wxString::Format(wxT("%i"), int(tolerance)));
		selected_tolerance->SetToolTip(_("Max tolerance of the color."));

		selected_x->Bind(wxEVT_TEXT, &DialogAlignToVideo::update_from_textbox, this);
		selected_y->Bind(wxEVT_TEXT, &DialogAlignToVideo::update_from_textbox, this);
		update_from_textbox();

		wxFlexGridSizer* right_sizer = new wxFlexGridSizer(4, 2, 5, 5);
		add_with_label(right_sizer, _("X"), selected_x);
		add_with_label(right_sizer, _("Y"), selected_y);
		add_with_label(right_sizer, _("Color"), selected_color);
		add_with_label(right_sizer, _("Tolerance"), selected_tolerance);
		right_sizer->AddGrowableCol(1, 1);

		wxSizer* main_sizer = new wxBoxSizer(wxHORIZONTAL);

		main_sizer->Add(preview_frame, 1, (wxALL & ~wxRIGHT) | wxEXPAND, 5);
		main_sizer->Add(right_sizer, 0, wxALIGN_LEFT, 5);

		wxSizer* dialog_sizer = new wxBoxSizer(wxVERTICAL);
		dialog_sizer->Add(main_sizer, wxSizerFlags(1).Border(wxALL & ~wxBOTTOM).Expand());
		dialog_sizer->Add(CreateButtonSizer(wxOK | wxCANCEL), wxSizerFlags().Right().Border());
		SetSizerAndFit(dialog_sizer);
		SetSize(1024, 700);
		CenterOnParent();

		Bind(wxEVT_BUTTON, &DialogAlignToVideo::process, this, wxID_OK);
		SetIcon(GETICON(button_align_16));
		if (maximized)
			wxDialog::Maximize(true);
	}

	DialogAlignToVideo::~DialogAlignToVideo()
	{
		long lt;
		if (!selected_tolerance->GetValue().ToLong(&lt))
			return;
		if (lt < 0 || lt > 255)
			return;

		OPT_SET("Tool/Align to Video/Tolerance")->SetInt(lt);
	}

	void rgb2lab(unsigned char r, unsigned char g, unsigned char b, double* lab)
	{
		double R = static_cast<double>(r) / 255.0;
		double G = static_cast<double>(g) / 255.0;
		double B = static_cast<double>(b) / 255.0;
		double X = 0.412453 * R + 0.357580 * G + 0.180423 * B;
		double Y = 0.212671 * R + 0.715160 * G + 0.072169 * B;
		double Z = 0.019334 * R + 0.119193 * G + 0.950227 * B;
		double xr = X / 0.950456, yr = Y / 1.000, zr = Z / 1.088854;

		if (yr > 0.008856) {
			lab[0] = 116.0 * pow(yr, 1.0 / 3.0) - 16.0;
		}
		else {
			lab[0] = 903.3 * yr;
		}

		double fxr, fyr, fzr;
		if (xr > 0.008856)
			fxr = pow(xr, 1.0 / 3.0);
		else
			fxr = 7.787 * xr + 16.0 / 116.0;

		if (yr > 0.008856)
			fyr = pow(yr, 1.0 / 3.0);
		else
			fyr = 7.787 * yr + 16.0 / 116.0;

		if (zr > 0.008856)
			fzr = pow(zr, 1.0 / 3.0);
		else
			fzr = 7.787 * zr + 16.0 / 116.0;

		lab[1] = 500.0 * (fxr - fyr);
		lab[2] = 200.0 * (fyr - fzr);
	}

	template<typename T>
	bool check_point(boost::gil::pixel<unsigned char, T> & pixel, double orig[3], unsigned char tolerance)
	{
		double lab[3];
		// in pixel: B,G,R
		rgb2lab(pixel[2], pixel[1], pixel[0], lab);
		auto diff = sqrt(pow(lab[0] - orig[0], 2) + pow(lab[1] - orig[1], 2) + pow(lab[2] - orig[2], 2));
		return diff < tolerance;
	}

	template<typename T>
	bool calculate_point(boost::gil::image_view<T> view, int x, int y, double orig[3], unsigned char tolerance, int* ret)
	{
		auto origin = *view.at(x, y);
		if (!check_point(origin, orig, tolerance))
			return false;
		auto w = view.width();
		auto h = view.height();
		int l = x, r = x, u = y, d = y;
		for (int i = x + 1; i < w; i++)
		{
			auto p = *view.at(i, y);
			if (!check_point(p, orig, tolerance))
			{
				r = i;
				break;
			}
		}

		for (int i = x - 1; i >= 0; i--)
		{
			auto p = *view.at(i, y);
			if (!check_point(p, orig, tolerance))
			{
				l = i;
				break;
			}
		}

		for (int i = y + 1; i < h; i++)
		{
			auto p = *view.at(x, i);
			if (!check_point(p, orig, tolerance))
			{
				d = i;
				break;
			}
		}

		for (int i = y - 1; i >= 0; i--)
		{
			auto p = *view.at(x, i);
			if (!check_point(p, orig, tolerance))
			{
				u = i;
				break;
			}
		}
		ret[0] = l;
		ret[1] = r;
		ret[2] = u;
		ret[3] = d;
		return true;
	}

	void DialogAlignToVideo::process(wxCommandEvent & evt)
	{
		auto n_frames = provider->GetFrameCount();
		auto w = provider->GetWidth();
		auto h = provider->GetHeight();

		long lx, ly, lt;
		if (!selected_x->GetValue().ToLong(&lx) || !selected_y->GetValue().ToLong(&ly) || !selected_tolerance->GetValue().ToLong(&lt))
		{
			wxMessageBox(_("Bad x or y position or tolerance value!"));
			evt.Skip();
			return;
		}
		if (lx < 0 || ly < 0 || lx >= w || ly >= h)
		{
			wxMessageBox(wxString::Format(_("Bad x or y position! Require: 0 <= x < %i, 0 <= y < %i"), w, h));
			evt.Skip();
			return;
		}
		if (lt < 0 || lt > 255)
		{
			wxMessageBox(_("Bad tolerance value! Require: 0 <= torlerance <= 255"));
			evt.Skip();
			return;
		}
		int x = int(lx), y = int(ly);
		unsigned char tolerance = unsigned char(lt);

		auto color = selected_color->GetColor();
		auto r = color.r;
		auto b = color.b;
		auto g = color.g;
		double lab[3];
		rgb2lab(r, g, b, lab);

		int pos = current_n_frame;
		auto frame = provider->GetFrame(pos, -1, true);
		auto view = interleaved_view(frame->width, frame->height, reinterpret_cast<boost::gil::bgra8_pixel_t*>(frame->data.data()), frame->pitch);
		if (frame->flipped)
			y = frame->height - y;
		int lrud[4];
		calculate_point(view, x, y, lab, tolerance, lrud);

		// find forward
#define CHECK_EXISTS_POS check_exists(pos, x, y, lrud, lab, tolerance)
		while (pos >= 0)
		{
			if (CHECK_EXISTS_POS)
				pos -= 2;
			else break;
		}
		pos++;
		pos = std::max(0, pos);
		auto left = CHECK_EXISTS_POS ? pos : pos + 1;

		pos = current_n_frame;
		while (pos < n_frames)
		{
			if (CHECK_EXISTS_POS)
				pos += 2;
			else break;
		}
		pos--;
		pos = std::min(pos, n_frames - 1);
		auto right = CHECK_EXISTS_POS ? pos : pos - 1;

		auto timecode = context->project->Timecodes();
		auto line = context->selectionController->GetActiveLine();
		line->Start = timecode.TimeAtFrame(left);
		line->End = timecode.TimeAtFrame(right + 1); // exclusive
		context->ass->Commit(_("Align to video by key point"), AssFile::COMMIT_DIAG_TIME);
		Close();
	}



	bool DialogAlignToVideo::check_exists(int pos, int x, int y, int* lrud, double* orig, unsigned char tolerance)
	{
		auto frame = provider->GetFrame(pos, -1, true);
		auto view = interleaved_view(frame->width, frame->height, reinterpret_cast<boost::gil::bgra8_pixel_t*>(frame->data.data()), frame->pitch);
		if (frame->flipped)
			y = frame->height - y;
		int actual[4];
		if (!calculate_point(view, x, y, orig, tolerance, actual)) return false;
		int dl = abs(actual[0] - lrud[0]);
		int dr = abs(actual[1] - lrud[1]);
		int du = abs(actual[2] - lrud[2]);
		int dd = abs(actual[3] - lrud[3]);

		return dl <= 5 && dr <= 5 && du <= 5 && dd <= 5;
	}

	void DialogAlignToVideo::update_from_textbox()
	{
		long lx, ly;
		int w = preview_image.GetWidth(), h = preview_image.GetHeight();
		if (!selected_x->GetValue().ToLong(&lx) || !selected_y->GetValue().ToLong(&ly))
			return;

		if (lx < 0 || ly < 0 || lx >= w || ly >= h)
			return;
		int x = int(lx);
		int y = int(ly);
		auto r = preview_image.GetRed(x, y);
		auto g = preview_image.GetGreen(x, y);
		auto b = preview_image.GetBlue(x, y);
		selected_color->SetColor(agi::Color(r, g, b));
	}

	void DialogAlignToVideo::update_from_textbox(wxCommandEvent & evt)
	{
		update_from_textbox();
	}

}


void ShowAlignToVideoDialog(agi::Context * c)
{
	c->dialog->Show<DialogAlignToVideo>(c);
}
