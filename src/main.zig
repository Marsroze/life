const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});

// Constants
const SCREEN_WIDTH = 640;
const SCREEN_HEIGHT = 480;
const CELL_SIZE = 10;
const ROWS = SCREEN_WIDTH / CELL_SIZE;
const COLS = SCREEN_HEIGHT / CELL_SIZE;
const FPS = 30;

// Color struct
const Color = struct {
    r: u8, // red
    g: u8, // green
    b: u8, // blue
    a: u8, // alpha
};

// Color for alive cells
const ALIVE = Color{
    .r = 45,
    .g = 198,
    .b = 83,
    .a = 0xff,
};

// Color for grid lines
const LINES = Color{
    .r = 233,
    .g = 236,
    .b = 239,
    .a = 0xff,
};

// Background color
const BG = Color{
    .r = 0xff,
    .g = 0xff,
    .b = 0xff,
    .a = 0xff,
};

// Game struct
const Game = struct {
    renderer: *c.SDL_Renderer, // SDL renderer
    grid: [ROWS][COLS]bool, // Grid
    next: [ROWS][COLS]bool, // Next grid

    const Self = @This();

    // Constructor
    fn init(renderer: *c.SDL_Renderer) Self {
        return Self{
            .renderer = renderer,
            .grid = [_][COLS]bool{[1]bool{false} ** COLS} ** ROWS,
            .next = [_][COLS]bool{[1]bool{false} ** COLS} ** ROWS,
        };
    }

    // Draws the grid
    fn drawGrid(self: Self) void {
        // zig fmt: off
        // Grid color
        _ = c.SDL_SetRenderDrawColor(
            self.renderer,
            LINES.r,
            LINES.g,
            LINES.b, 
            LINES.a,
        );
        // zig fmt: on
        var i: usize = 0;
        while (i < ROWS) : (i += 1) {
            var j: usize = 0;
            while (j < COLS) : (j += 1) {
                // zig fmt: off
                const box = c.SDL_Rect{
                    .x = @intCast(c_int, i * CELL_SIZE),
                    .y = @intCast(c_int, j * CELL_SIZE),
                    .w = CELL_SIZE,
                    .h = CELL_SIZE,
                };
                // zig fmt: on
                _ = c.SDL_RenderDrawRect(self.renderer, &box);
            }
        }
    }

    // Count numbers of alive neighbours of a cell
    fn countNeighbours(self: Self, x: usize, y: usize) u4 {
        var count: u4 = 0;

        // Dealing with edge cases (TT)
        var xmin: usize = undefined;
        var xmax: usize = undefined;
        var ymin: usize = undefined;
        var ymax: usize = undefined;
        if (x == 0) {
            xmin = 0;
        } else {
            xmin = x - 1;
        }
        if (x == ROWS - 1) {
            xmax = ROWS - 1;
        } else {
            xmax = x + 1;
        }
        if (y == 0) {
            ymin = 0;
        } else {
            ymin = y - 1;
        }
        if (y == COLS - 1) {
            ymax = COLS - 1;
        } else {
            ymax = y + 1;
        }

        var i: usize = xmin;
        while (i <= xmax) : (i += 1) {
            var j: usize = ymin;
            while (j <= ymax) : (j += 1) {
                if (self.grid[i][j]) {
                    if (i != x or j != y) {
                        count += 1;
                    }
                }
            }
        }
        return count;
    }

    // Draws alive cells in the grid
    fn drawCells(self: Self) void {
        var i: usize = 0;
        while (i < ROWS) : (i += 1) {
            var j: usize = 0;
            while (j < COLS) : (j += 1) {
                if (self.grid[i][j]) {
                    // zig fmt: off
                    const cell = c.SDL_Rect{
                        .x = @intCast(c_int, i * CELL_SIZE),
                        .y = @intCast(c_int, j * CELL_SIZE),
                        .w = CELL_SIZE,
                        .h = CELL_SIZE
                    };
                    _ = c.SDL_SetRenderDrawColor(
                        self.renderer,
                        ALIVE.r,
                        ALIVE.g,
                        ALIVE.b,
                        ALIVE.a,
                    );
                    // zig fmt: on
                    _ = c.SDL_RenderFillRect(self.renderer, &cell);
                }
            }
        }
    }

    // Toggle cell state
    fn setState(self: *Self, x: usize, y: usize) void {
        self.grid[x][y] = !self.grid[x][y];
    }

    // Updates the grid state
    fn update(self: *Self) void {
        self.next = self.grid;
        var i: usize = 0;
        while (i < ROWS) : (i += 1) {
            var j: usize = 0;
            while (j < COLS) : (j += 1) {
                const alive = self.countNeighbours(i, j);
                if (!self.grid[i][j]) {
                    if (alive == 3) {
                        self.next[i][j] = true;
                    }
                } else {
                    if (alive != 2 and alive != 3) {
                        self.next[i][j] = false;
                    }
                }
            }
        }
        self.grid = self.next;
    }
};

pub fn main() !void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    // zig fmt: off
    // Creates a window
    var window = c.SDL_CreateWindow(
        "Game of life",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        0
    );
    // zig fmt: on
    defer c.SDL_DestroyWindow(window);

    // zig fmt: off
    // SDL Renderer
    var renderer = c.SDL_CreateRenderer(
        window,
        0,
        c.SDL_RENDERER_PRESENTVSYNC
    );
    // zig fmt: on
    defer c.SDL_DestroyRenderer(renderer);

    const ticks_per_frame: c_uint = 1000 / FPS;
    var framestart: c_uint = undefined;
    var frametime: c_int = undefined;
    var paused = true;

    var game = Game.init(renderer.?);

    mainloop: while (true) {
        framestart = c.SDL_GetTicks();
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                c.SDL_MOUSEBUTTONDOWN => {
                    var x: c_int = undefined;
                    var y: c_int = undefined;
                    _ = c.SDL_GetMouseState(&x, &y);
                    const i = @intCast(usize, @divFloor(x, CELL_SIZE));
                    const j = @intCast(usize, @divFloor(y, CELL_SIZE));
                    game.setState(i, j);
                },
                c.SDL_KEYDOWN => {
                    switch (sdl_event.key.keysym.sym) {
                        ' ' => {
                            paused = !paused;
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }
        // zig fmt: off
        // BG color
        _ = c.SDL_SetRenderDrawColor(
            renderer,
            BG.r,
            BG.g,
            BG.b,
            BG.a,
        );
        // zig fmt: on
        _ = c.SDL_RenderClear(renderer);
        game.drawGrid();
        game.drawCells();
        if (!paused) {
            game.update();
        }
        c.SDL_RenderPresent(renderer);
        frametime = @intCast(c_int, c.SDL_GetTicks() - framestart);
        if (ticks_per_frame > frametime) {
            c.SDL_Delay(ticks_per_frame - @intCast(c_uint, frametime));
        }
    }
}
