-- conky_nothing.lua
-- Nothing Phone-Inspired Conky LUA Script
-- Custom drawing routines for minimalist visuals

require 'cairo'

-- Color definitions (RGBA, 0-1 range)
local COLOR = {
    bg         = {0.00, 0.00, 0.00, 0.92},   -- pure black panel
    bg_card    = {0.08, 0.08, 0.08, 0.95},   -- subtle card
    border     = {0.22, 0.22, 0.22, 0.55},   -- panel border
    primary    = {0.96, 0.96, 0.96, 1.00},   -- bright white text
    secondary  = {0.55, 0.55, 0.55, 1.00},   -- secondary text
    dim        = {0.22, 0.22, 0.22, 1.00},   -- dim elements
    accent     = {0.90, 0.90, 0.90, 1.00},   -- accent / ring fill
    glyph      = {0.85, 0.85, 0.85, 0.70},   -- glyph decorations
    bar_fill   = {0.88, 0.88, 0.88, 0.90},   -- progress bar fill
    bar_bg     = {0.14, 0.14, 0.14, 1.00},   -- progress bar background
    dot_on     = {0.95, 0.95, 0.95, 1.00},   -- active ring dot
    dot_off    = {0.12, 0.12, 0.12, 1.00},   -- inactive ring dot
    tick_major = {0.70, 0.70, 0.70, 0.90},   -- major tick mark
}

-- Panel geometry
local PANEL = {
    x      = 1610,  -- right-side panel (screen_width - gap_x - widget_width = 1920-30-280)
    y      = 50,
    w      = 280,
    h      = 660,
    radius = 18,
}

-- Helper: set source color from table
local function set_color(cr, c)
    cairo_set_source_rgba(cr, c[1], c[2], c[3], c[4])
end

-- Helper: rounded rectangle path
local function rounded_rect(cr, x, y, w, h, r)
    cairo_new_sub_path(cr)
    cairo_arc(cr, x + w - r, y + r,     r, -math.pi/2,  0)
    cairo_arc(cr, x + w - r, y + h - r, r,  0,           math.pi/2)
    cairo_arc(cr, x + r,     y + h - r, r,  math.pi/2,   math.pi)
    cairo_arc(cr, x + r,     y + r,     r,  math.pi,     3*math.pi/2)
    cairo_close_path(cr)
end

-- Helper: draw a filled rounded rectangle
local function fill_rounded_rect(cr, x, y, w, h, r, color)
    set_color(cr, color)
    rounded_rect(cr, x, y, w, h, r)
    cairo_fill(cr)
end

-- Helper: draw a stroked rounded rectangle
local function stroke_rounded_rect(cr, x, y, w, h, r, lw, color)
    set_color(cr, color)
    cairo_set_line_width(cr, lw)
    rounded_rect(cr, x, y, w, h, r)
    cairo_stroke(cr)
end

-- Draw a thin horizontal separator line
local function draw_separator(cr, x, y, w, alpha)
    alpha = alpha or 0.55
    cairo_set_source_rgba(cr, COLOR.border[1], COLOR.border[2], COLOR.border[3], alpha)
    cairo_set_line_width(cr, 0.6)
    cairo_move_to(cr, x, y)
    cairo_line_to(cr, x + w, y)
    cairo_stroke(cr)
end

-- Draw a rounded progress bar
local function draw_bar(cr, x, y, w, h, pct, r)
    r = r or 3
    fill_rounded_rect(cr, x, y, w, h, r, COLOR.bar_bg)
    local fw = math.max(2 * r, w * math.min(pct / 100.0, 1.0))
    fill_rounded_rect(cr, x, y, fw, h, r, COLOR.bar_fill)
end

-- Draw battery indicator as segmented dot row
local function draw_battery_dots(cr, x, y, pct)
    local segments = 12
    local total_w  = 220
    local gap      = 3
    local seg_w    = (total_w - gap * (segments - 1)) / segments
    local seg_h    = 7
    local r        = 2
    local filled   = math.floor(pct / 100.0 * segments + 0.5)
    for i = 0, segments - 1 do
        local sx  = x + i * (seg_w + gap)
        local col = (i < filled) and COLOR.bar_fill or COLOR.bar_bg
        fill_rounded_rect(cr, sx, y, seg_w, seg_h, r, col)
    end
end

-- Draw the Nothing Phone-style minute/second dot ring
local function draw_clock_ring(cr, cx, cy, radius, min_pct, sec_pct)
    local steps     = 60
    local dot_r_std = 1.6
    local dot_r_big = 2.8
    local filled    = math.floor(min_pct * steps)
    local sec_idx   = math.floor(sec_pct * steps)

    for i = 0, steps - 1 do
        local angle = -math.pi / 2 + (2 * math.pi / steps) * i
        local dx    = cx + radius * math.cos(angle)
        local dy    = cy + radius * math.sin(angle)

        -- Major tick at every 5th dot (like a clock face)
        local is_major = (i % 5 == 0)
        -- Current second dot is brighter and larger
        local is_sec   = (i == sec_idx)

        local dot_r
        local col
        if is_sec then
            dot_r = dot_r_big
            col   = COLOR.dot_on
        elseif i < filled then
            dot_r = is_major and dot_r_std + 0.4 or dot_r_std
            col   = is_major and COLOR.tick_major or COLOR.accent
        else
            dot_r = is_major and dot_r_std or dot_r_std - 0.3
            col   = COLOR.dot_off
        end

        set_color(cr, col)
        cairo_arc(cr, dx, dy, dot_r, 0, 2 * math.pi)
        cairo_fill(cr)
    end
end

-- Draw the Nothing Phone glyph accent strip (diagonal line motif)
local function draw_glyph_strip(cr, px, py, pw, ph)
    -- Bottom-left diagonal accent  (Nothing Phone 1 "slant" glyph)
    set_color(cr, COLOR.glyph)
    cairo_set_line_width(cr, 1.2)
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
    cairo_move_to(cr, px + 16,       py + ph - 22)
    cairo_line_to(cr, px + pw - 16,  py + ph - 22)
    cairo_stroke(cr)

    -- USB-C dot at the bottom (Nothing Phone glyph motif)
    set_color(cr, COLOR.glyph)
    local ux = px + pw / 2
    local uy = py + ph - 10
    cairo_arc(cr, ux, uy, 3, 0, 2 * math.pi)
    cairo_fill(cr)

    -- Two flanking dots
    for _, ox in ipairs({-18, 18}) do
        cairo_arc(cr, ux + ox, uy, 1.5, 0, 2 * math.pi)
        cairo_fill(cr)
    end
end

-- Draw four corner glyph dots
local function draw_corner_dots(cr, px, py, pw, ph)
    local positions = {
        {px + 14,      py + 14},
        {px + pw - 14, py + 14},
        {px + 14,      py + ph - 14},
        {px + pw - 14, py + ph - 14},
    }
    for _, pos in ipairs(positions) do
        set_color(cr, COLOR.dim)
        cairo_arc(cr, pos[1], pos[2], 2.2, 0, 2 * math.pi)
        cairo_fill(cr)
    end
end

-- Draw a thin arc progress ring (for CPU or battery).
-- Not used in draw_background by default; available for callers that want
-- a circular gauge instead of a bar (e.g. draw_arc_ring for per-core rings).
local function draw_arc_ring(cr, cx, cy, r, lw, pct, fg, bg)
    local start = -math.pi / 2
    local stop  = start + 2 * math.pi * math.min(pct / 100.0, 1.0)
    -- background arc
    set_color(cr, bg)
    cairo_set_line_width(cr, lw)
    cairo_arc(cr, cx, cy, r, 0, 2 * math.pi)
    cairo_stroke(cr)
    -- foreground arc
    if pct > 0 then
        set_color(cr, fg)
        cairo_arc(cr, cx, cy, r, start, stop)
        cairo_stroke(cr)
    end
end

-- ──────────────────────────────────────────────────────────────
-- Main draw hook – called by Conky before text rendering
-- ──────────────────────────────────────────────────────────────
function draw_background(w, h)
    -- Guard: conky_window is not yet available on the first update cycle
    if conky_window == nil then return end

    -- Obtain the cairo surface from the Conky display
    local cs = cairo_xlib_surface_create(
                   conky_window.display,
                   conky_window.drawable,
                   conky_window.visual,
                   w, h)
    local cr = cairo_create(cs)

    local px = PANEL.x
    local py = PANEL.y
    local pw = PANEL.w
    local ph = PANEL.h

    -- ── Background card ──────────────────────────────────────
    fill_rounded_rect  (cr, px, py, pw, ph, PANEL.radius, COLOR.bg)
    stroke_rounded_rect(cr, px, py, pw, ph, PANEL.radius, 0.8, COLOR.border)

    -- ── Corner glyph dots ─────────────────────────────────────
    draw_corner_dots(cr, px, py, pw, ph)

    -- ── Minute + second dot ring around clock ─────────────────
    local min_val  = tonumber(os.date("%M"))
    local sec_val  = tonumber(os.date("%S"))
    local min_pct  = min_val / 60.0
    local sec_pct  = sec_val / 60.0
    local ring_cx  = px + pw / 2
    local ring_cy  = py + 72
    draw_clock_ring(cr, ring_cx, ring_cy, 52, min_pct, sec_pct)

    -- ── Section header divider below clock ───────────────────
    draw_separator(cr, px + 16, py + 136, pw - 32)

    -- ── Section cards ────────────────────────────────────────
    local sections = {
        {y = py + 148, h = 102},  -- system stats
        {y = py + 262, h = 80},   -- cpu cores
        {y = py + 354, h = 62},   -- battery
        {y = py + 428, h = 60},   -- network
        {y = py + 500, h = 78},   -- now playing
    }
    for _, s in ipairs(sections) do
        fill_rounded_rect(cr, px + 6, s.y, pw - 12, s.h, 10, COLOR.bg_card)
        stroke_rounded_rect(cr, px + 6, s.y, pw - 12, s.h, 10, 0.5, COLOR.border)
    end

    -- ── Bottom glyph strip ────────────────────────────────────
    draw_glyph_strip(cr, px, py, pw, ph)

    -- Clean up
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

-- ──────────────────────────────────────────────────────────────
-- Utility: parse a header line (called from conky.text)
-- ──────────────────────────────────────────────────────────────
function conky_header()
    return ""   -- visual header drawn in draw_background
end
