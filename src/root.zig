const std = @import("std");

var allocator = std.heap.GeneralPurposeAllocator(.{}){};
var alloc = allocator.allocator();

const c_std = @cImport({
    @cInclude("string.h");
});
// - [ImageMagick – Sitemap](https://imagemagick.org/script/sitemap.php#program-interfaces)
// - [ImageMagick – MagickWand, C API](https://imagemagick.org/script/magick-wand.php)
// - [ImageMagick – MagickCore, Low-level C API](https://imagemagick.org/script/magick-core.php)
const magick = @cImport({
    // @cInclude("MagickCore/MagickCore.h");
    @cDefine("MAGICKCORE_HDRI_ENABLE", "1");
    @cInclude("MagickWand/MagickWand.h");
});
const zathura = @cImport({
    @cInclude("zathura/document.h");
    @cInclude("zathura/links.h");
    @cInclude("zathura/macros.h");
    @cInclude("zathura/page.h");
    @cInclude("zathura/plugin-api.h");
    @cInclude("zathura/types.h");
    @cInclude("zathura/zathura-version.h");
});

const mime_types = [_][*c]const u8{ "image/jpeg", "image/png", "inode/directory" };
export const zathura_plugin_5_6 = zathura.zathura_plugin_definition_t{
    .name = "zathura-images",
    .version = .{ .rev = 1, .minor = 0, .major = 0 },
    .mime_types = @constCast(mime_types[0..mime_types.len].ptr),
    .mime_types_size = mime_types.len,
    .functions = .{
        .document_open = &plugin_open,
        // .document_free = ,
        // .document_get_information = &plugin_get_information,
        .page_init = &plugin_page_init,
        // .page_clear = ,
        .page_render_cairo = &plugin_page_render_cairo,
    },
};

fn plugin_page_render_cairo(page: ?*zathura.zathura_page_t, data: ?*anyopaque, context: ?*zathura.cairo_t, printing: bool) callconv(.C) zathura.zathura_error_t {
    const err = zathura.ZATHURA_ERROR_UNKNOWN;
    _ = data;
    _ = printing;
    const doc = zathura.zathura_page_get_document(page);
    const surface = zathura.cairo_get_target(context);

    const surface_width: usize = @intCast(zathura.cairo_image_surface_get_width(surface));
    const surface_height: usize = @intCast(zathura.cairo_image_surface_get_height(surface));

    const page_width: i32 = @intFromFloat(zathura.zathura_page_get_width(page));
    const page_height: i32 = @intFromFloat(zathura.zathura_page_get_height(page));

    const image = zathura.cairo_image_surface_get_data(surface);

    // const state: *State = @ptrCast(@alignCast(data orelse return err));
    const state: *State = @ptrCast(@alignCast(zathura.zathura_document_get_data(doc)));

    std.debug.print("page render {*} {} {} {} {}\n", .{ page, surface_width, surface_height, page_width, page_height });

    // _ = magick.MagickNextImage(state.wand);
    const index = zathura.zathura_page_get_index(page);

    const wand = magick.CloneMagickWand(state.wand);
    defer _ = magick.DestroyMagickWand(wand);
    const pwand = magick.NewPixelWand();
    defer _ = magick.DestroyPixelWand(pwand);
    var s = magick.PixelSetColor(pwand, "#28282800");
    if (s == magick.MagickFalse) {
        std.debug.print("could not read image\n", .{});
        return err;
    }
    s = magick.MagickSetBackgroundColor(wand, pwand);
    if (s == magick.MagickFalse) {
        std.debug.print("could not read image\n", .{});
        return err;
    }
    const stat = magick.MagickReadImage(wand, state.files.items[index].ptr);
    if (stat == magick.MagickFalse) {
        std.debug.print("could not read image", .{});
        return err;
    }
    // _ = magick.MagickResizeImage(wand, @intCast(surface_width), @intCast(surface_height), magick.TriangleFilter);
    // _ = magick.MagickSampleImage(wand, @intCast(surface_width), @intCast(surface_height));
    // _ = magick.MagickScaleImage(wand, @intCast(surface_width), @intCast(surface_height));
    _ = magick.MagickExtentImage(wand, surface_width, surface_height, 0, 0);
    const ret = magick.MagickExportImagePixels(wand, 0, 0, surface_width, surface_height, "BGRA", magick.CharPixel, image);
    if (ret == magick.MagickFalse) {
        return err;
    }

    // HUH: ? transparency does not work?
    // for (0..surface_height) |y| {
    //     for (0..surface_width) |x| {
    //         image[(y * surface_width + x) * 4] = 0;
    //         image[(y * surface_width + x) * 4 + 1] = 0;
    //         image[(y * surface_width + x) * 4 + 2] = 0;
    //         image[(y * surface_width + x) * 4 + 3] = 255;
    //     }
    // }

    return zathura.ZATHURA_ERROR_OK;
}

fn plugin_page_init(page: ?*zathura.zathura_page_t) callconv(.C) zathura.zathura_error_t {
    const doc = zathura.zathura_page_get_document(page);
    const state: *State = @ptrCast(@alignCast(zathura.zathura_document_get_data(doc)));

    const index = zathura.zathura_page_get_index(page);
    const path = state.files.items[index];

    const stat = magick.MagickPingImage(state.wand, path.ptr);
    if (stat == magick.MagickFalse) {
        std.debug.print("could not read image", .{});
        return zathura.ZATHURA_ERROR_UNKNOWN;
    }
    const width = magick.MagickGetImageWidth(state.wand);
    const height = magick.MagickGetImageHeight(state.wand);
    _ = magick.MagickRemoveImage(state.wand);

    std.debug.print("page: {*}, width: {}, height: {}, path: {s}\n", .{ page, width, height, path });
    // zathura.zathura_page_set_data(page, state);
    zathura.zathura_page_set_width(page, @floatFromInt(width));
    zathura.zathura_page_set_height(page, @floatFromInt(height));

    return zathura.ZATHURA_ERROR_OK;
}

const State = struct {
    const Self = @This();
    const PathArray = std.ArrayList([]const u8);

    dir: std.fs.Dir,
    files: PathArray,
    opened: usize,

    wand: *magick.MagickWand,

    fn new(_path: [*:0]const u8) !Self {
        const path_strlen = c_std.strlen(_path);
        var path = _path[0..path_strlen];
        const cwd = std.fs.cwd();
        const fod = try cwd.openFile(path, .{});
        defer fod.close();
        const stat = try fod.stat();

        var dir: std.fs.Dir = undefined;
        var files = PathArray.init(alloc);
        switch (stat.kind) {
            .directory => {
                dir = try cwd.openDir(path, .{ .iterate = true });
            },
            else => {
                const dirpath = std.fs.path.dirname(path) orelse unreachable;
                dir = try cwd.openDir(dirpath, .{ .iterate = true });
                path = dirpath;
            },
        }
        var iter = dir.iterate();
        while (try iter.next()) |p| {
            switch (p.kind) {
                .file => {
                    if (std.mem.eql(u8, std.fs.path.extension(p.name), ".png")) {
                        const path_parts: [2][]const u8 = .{ path, p.name };
                        const joined_path = try std.fs.path.joinZ(alloc, path_parts[0..]);
                        try files.append(joined_path);
                    }
                },
                else => {},
            }
        }

        magick.MagickWandGenesis();
        const wand = magick.NewMagickWand() orelse {
            return error.CouldNotGetWand;
        };

        return .{
            .dir = dir,
            .files = files,
            .opened = 0,
            .wand = wand,
        };
    }

    fn deinit(self: *Self) void {
        self.dir.close();
        self.opened.close();
    }
};

fn plugin_open(doc: ?*zathura.zathura_document_t) callconv(.C) zathura.zathura_error_t {
    const err = zathura.ZATHURA_ERROR_UNKNOWN;
    if (doc == null) {
        return err;
    }

    const p = zathura.zathura_document_get_path(doc);
    const state = alloc.create(State) catch return err;
    state.* = State.new(p) catch unreachable;

    zathura.zathura_document_set_data(doc, state);

    zathura.zathura_document_set_number_of_pages(doc, @intCast(state.files.items.len));
    return zathura.ZATHURA_ERROR_OK;
}

fn plugin_get_information(
    doc: ?*zathura.zathura_document_t,
    data: ?*void,
    err: ?*zathura.zathura_error_t,
) callconv(.C) ?*zathura.girara_list_t {
    _ = doc;
    _ = data;
    _ = err;
    return null;
}
