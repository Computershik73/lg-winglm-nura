/*
 * Copyright (C) 2026 LG Wing postmarketOS port
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#pragma once

#include <adwaita.h>

G_BEGIN_DECLS

#define CALLS_TYPE_DIALPAD_WINDOW (calls_dialpad_window_get_type ())

G_DECLARE_FINAL_TYPE (CallsDialpadWindow, calls_dialpad_window, CALLS, DIALPAD_WINDOW, AdwWindow)

CallsDialpadWindow *calls_dialpad_window_new (GtkApplication *application,
                                              GtkWindow      *main_window,
                                              GtkWindow      *call_window);

G_END_DECLS
