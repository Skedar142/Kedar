-- conky_nothing.lua
-- Nothing Phone-Inspired Conky LUA Script
-- Custom drawing routines for minimalist visuals

require 'cairo'

-- Color definitions (RGBA, 0-1 range) — vibrant purple/violet palette
local COLOR = {
    bg         = {0.05, 0.03, 0.10, 0.88},  -- very dark purple-black
    bg_card    = {0.11, 0.08, 0.18, 0.92},  -- dark purple card
    border     = {0.45, 0.28, 0.72, 0.65},  -- glowing purple border
    primary    = {0.97, 0.95, 1.00, 1.00},  -- near-white with lavender tint
    secondary  = {0.68, 0.57, 0.83, 1.00},  -- soft lavender
    dim        = {0.38, 0.27, 0.55, 1.00},  -- muted purple
    accent     = {0.62, 0.31, 0.87, 1.00},  -- vivid violet
    bar_fill   = {0.55, 0.18, 0.90, 0.90},  -- electric purple bar fill
    bar_bg     = {0.16, 0.10, 0.26, 1.00},  -- dark purple bar background
}

-- Panel geometry
local PANEL = {
    x      = 1610,  -- right-side panel (screen_width - gap_x - widget_width = 1920-30-280)
    y      = 50,
    w      = 280,
    h      = 635,
    radius = 14,
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
local function draw_separator(cr, x, y, w)
    set_color(cr, COLOR.border)
    cairo_set_line_width(cr, 0.5)
    cairo_move_to(cr, x, y)
    cairo_line_to(cr, x + w, y)
    cairo_stroke(cr)
end

-- Draw a minimal progress bar
local function draw_bar(cr, x, y, w, h, pct, r)
    r = r or 3
    -- background
    fill_rounded_rect(cr, x, y, w, h, r, COLOR.bar_bg)
    -- fill
    local fw = math.max(2 * r, w * math.min(pct / 100.0, 1.0))
    fill_rounded_rect(cr, x, y, fw, h, r, COLOR.bar_fill)
end

-- Draw battery indicator (segmented dot row)
local function draw_battery_dots(cr, x, y, pct)
    local segments = 10
    local seg_w    = 18
    local seg_h    = 8
    local gap      = 4
    local r        = 2
    local filled   = math.floor(pct / 100.0 * segments + 0.5)
    for i = 0, segments - 1 do
        local sx = x + i * (seg_w + gap)
        local col
        if i < filled then
            col = COLOR.bar_fill
        else
            col = COLOR.bar_bg
        end
        fill_rounded_rect(cr, sx, y, seg_w, seg_h, r, col)
    end
end

-- Draw small dot-matrix clock accent (decorative ring around hour)
local function draw_clock_ring(cr, cx, cy, radius, pct)
    local steps    = 60
    local dot_r    = 1.5
    local filled   = math.floor(pct * steps)
    for i = 0, steps - 1 do
        local angle = -math.pi / 2 + (2 * math.pi / steps) * i
        local dx    = cx + radius * math.cos(angle)
        local dy    = cy + radius * math.sin(angle)
        if i < filled then
            set_color(cr, COLOR.accent)
        else
            set_color(cr, COLOR.bar_bg)
        end
        cairo_arc(cr, dx, dy, dot_r, 0, 2 * math.pi)
        cairo_fill(cr)
    end
end

-- ──────────────────────────────────────────────────────────────
-- Main draw hook – called by Conky before text rendering
-- ──────────────────────────────────────────────────────────────
function draw_background(w, h)
    -- Guard: conky_window is not yet available on the first update cycle
    if conky_window == nil then return end

    -- Obtain the cairo surface from the Conky display
    local cs   = cairo_xlib_surface_create(
                     conky_window.display,
                     conky_window.drawable,
                     conky_window.visual,
                     w, h)
    local cr   = cairo_create(cs)

    local px   = PANEL.x
    local py   = PANEL.y
    local pw   = PANEL.w
    local ph   = PANEL.h

    -- ── Background card ──────────────────────────────────────
    fill_rounded_rect  (cr, px, py, pw, ph, PANEL.radius, COLOR.bg)
    stroke_rounded_rect(cr, px, py, pw, ph, PANEL.radius, 0.8, COLOR.border)

    -- ── Decorative corner dots (Nothing Phone glyph motif) ───
    local dot_positions = {
        {px + 12, py + 12},
        {px + pw - 12, py + 12},
        {px + 12, py + ph - 12},
        {px + pw - 12, py + ph - 12},
    }
    for _, pos in ipairs(dot_positions) do
        set_color(cr, COLOR.dim)
        cairo_arc(cr, pos[1], pos[2], 2, 0, 2 * math.pi)
        cairo_fill(cr)
    end

    -- ── Minute-ring accent above the clock ───────────────────
    local min_pct = tonumber(os.date("%M")) / 60.0
    draw_clock_ring(cr, px + pw / 2, py + 72, 46, min_pct)

    -- ── Section cards ────────────────────────────────────────
    -- (subtle inner cards for each data section)
    local sections = {
        {y = py + 160, h = 96},   -- system stats
        {y = py + 268, h = 76},   -- cpu cores
        {y = py + 356, h = 58},   -- battery
        {y = py + 426, h = 56},   -- network
        {y = py + 494, h = 72},   -- now playing
    }
    for _, s in ipairs(sections) do
        fill_rounded_rect(cr, px + 6, s.y, pw - 12, s.h, 8, COLOR.bg_card)
    end

    -- ── Glyph accent line (Nothing Phone signature element) ──
    set_color(cr, COLOR.accent)
    cairo_set_line_width(cr, 1.5)
    cairo_move_to(cr, px + 20, py + ph - 30)
    cairo_line_to(cr, px + pw - 20, py + ph - 30)
    cairo_stroke(cr)

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
