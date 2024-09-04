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

const State = struct {
    const Self = @This();
    const PathArray = std.ArrayList([:0]const u8);

    files: PathArray,
    opened: usize,
    page_synced: bool = false,

    wand: *magick.MagickWand,
    pwand: *magick.PixelWand,

    fn grab_files(path: []const u8) !PathArray {
        const dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
        var files = PathArray.init(alloc);
        errdefer files.deinit();
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
        return files;
    }

    fn new(path: []const u8) !Self {
        const fod = try std.fs.cwd().openFile(path, .{});
        defer fod.close();
        const stat = try fod.stat();

        var files: PathArray = undefined;
        var opened: usize = 0;
        switch (stat.kind) {
            .directory => {
                files = try grab_files(path);
            },
            else => {
                var buf = try alloc.alloc(u8, std.fs.max_path_bytes);
                defer alloc.free(buf);

                const real_file = try std.fs.realpath(path, buf[0..std.fs.max_path_bytes]);
                const dirpath = std.fs.path.dirname(real_file) orelse return error.NoParentToPath;
                files = try grab_files(dirpath);

                for (files.items, 0..) |file, i| {
                    if (std.mem.eql(u8, file, real_file)) {
                        opened = i;
                        break;
                    }
                }
            },
        }

        magick.MagickWandGenesis();
        const wand = magick.NewMagickWand() orelse {
            return error.CouldNotGetWand;
        };
        const pwand = magick.NewPixelWand() orelse {
            return error.CouldNotGetWand;
        };
        if (magick.PixelSetColor(pwand, "#28282800") == magick.MagickFalse) {
            return error.CouldNotSetPWandColor;
        }
        if (magick.MagickSetBackgroundColor(wand, pwand) == magick.MagickFalse) {
            return error.CouldNotSetBgColor;
        }

        return .{
            .files = files,
            .opened = opened,
            .wand = wand,
            .pwand = pwand,
        };
    }

    fn deinit(self: *Self) void {
        for (self.files.items) |f| {
            alloc.free(f);
        }
        self.files.deinit();
        _ = magick.DestroyMagickWand(self.wand);
        _ = magick.DestroyPixelWand(self.pwand);
    }

    // BGRA buffer
    fn render_to_buffer(self: *Self, page_index: usize, buffer: [*c]u8, buffer_width: usize, buffer_height: usize) !void {
        const buffer_ratio: f32 = @as(f32, @floatFromInt(buffer_width)) / @as(f32, @floatFromInt(buffer_height));

        const wand = magick.CloneMagickWand(self.wand);
        defer _ = magick.DestroyMagickWand(wand);
        if (magick.MagickReadImage(wand, self.files.items[page_index].ptr) == magick.MagickFalse) {
            return error.CouldNotReadImage;
        }

        const img_width = magick.MagickGetImageWidth(wand);
        const img_height = magick.MagickGetImageHeight(wand);
        const img_ratio: f32 = @as(f32, @floatFromInt(img_width)) / @as(f32, @floatFromInt(img_height));

        var width: usize = undefined;
        var height: usize = undefined;
        var xoff: isize = 0;
        var yoff: isize = 0;

        if (img_ratio > buffer_ratio) {
            const buffer_to_img_ratio = @as(f32, @floatFromInt(buffer_width)) / @as(f32, @floatFromInt(img_width));
            height = @intFromFloat(buffer_to_img_ratio * @as(f32, @floatFromInt(img_height)));
            width = buffer_width;
            yoff = @intCast((buffer_height - height) / 2);
        } else {
            const buffer_to_img_ratio = @as(f32, @floatFromInt(buffer_height)) / @as(f32, @floatFromInt(img_height));
            width = @intFromFloat(buffer_to_img_ratio * @as(f32, @floatFromInt(img_width)));
            height = buffer_height;
            xoff = @intCast((buffer_width - width) / 2);
        }

        // _ = magick.MagickResizeImage(wand, buffer_width, buffer_height, magick.TriangleFilter);
        // _ = magick.MagickSampleImage(wand, buffer_width, buffer_height));
        _ = magick.MagickScaleImage(wand, width, height);
        _ = magick.MagickExtentImage(wand, buffer_width, buffer_height, -xoff, -yoff);

        if (magick.MagickExportImagePixels(
            wand,
            0,
            0,
            buffer_width,
            buffer_height,
            "BGRA",
            magick.CharPixel,
            buffer,
        ) == magick.MagickFalse) {
            return error.CouldNotRenderToBuffer;
        }
    }
};

fn plugin_open(doc: ?*zathura.zathura_document_t) callconv(.C) zathura.zathura_error_t {
    const err = zathura.ZATHURA_ERROR_UNKNOWN;
    if (doc == null) {
        return err;
    }

    const p = zathura.zathura_document_get_path(doc);
    const state = alloc.create(State) catch return err;
    state.* = State.new(std.mem.span(p)) catch unreachable;

    zathura.zathura_document_set_data(doc, state);

    zathura.zathura_document_set_number_of_pages(doc, @intCast(state.files.items.len));

    // OOF: unfortunately this is overwritten soon after this function is called from zathura.c
    // zathura.zathura_document_set_current_page_number(doc, @intCast(state.opened));
    return zathura.ZATHURA_ERROR_OK;
}

fn plugin_document_free(doc: ?*zathura.zathura_document_t, data: ?*anyopaque) callconv(.C) zathura.zathura_error_t {
    _ = doc;
    var state: *State = @ptrCast(@alignCast(data orelse return zathura.ZATHURA_ERROR_UNKNOWN));
    state.deinit();
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
    // const width = 1000;
    // const height = 1000;
    _ = magick.MagickRemoveImage(state.wand);

    // zathura.zathura_page_set_data(page, state);
    zathura.zathura_page_set_width(page, @floatFromInt(width));
    zathura.zathura_page_set_height(page, @floatFromInt(height));

    return zathura.ZATHURA_ERROR_OK;
}

fn plugin_get_information(
    doc: ?*zathura.zathura_document_t,
    data: ?*anyopaque,
    err: ?*zathura.zathura_error_t,
) callconv(.C) ?*zathura.girara_list_t {
    _ = doc;
    _ = data;
    _ = err;
    return null;
}

fn plugin_page_label(page: ?*zathura.zathura_page_t, data: ?*anyopaque, label: [*c][*c]u8) callconv(.C) zathura.zathura_error_t {
    _ = data;
    const doc = zathura.zathura_page_get_document(page);
    const state: *State = @ptrCast(@alignCast(zathura.zathura_document_get_data(doc)));

    // OOF: hack to bypass zathura's page history system :(
    if (!state.page_synced) {
        state.page_synced = true;
        zathura.zathura_document_set_current_page_number(doc, @intCast(state.opened));
    }

    const index = zathura.zathura_page_get_index(page);
    const name = std.fs.path.basename(state.files.items[index]);
    label.* = @ptrCast(zathura.g_try_malloc0(name.len) orelse return zathura.ZATHURA_ERROR_UNKNOWN);
    std.mem.copyForwards(u8, label.*[0..1024], name);

    return zathura.ZATHURA_ERROR_OK;
}

fn plugin_page_render_cairo(page: ?*zathura.zathura_page_t, data: ?*anyopaque, context: ?*zathura.cairo_t, printing: bool) callconv(.C) zathura.zathura_error_t {
    _ = data;
    _ = printing;

    const doc = zathura.zathura_page_get_document(page);
    // const state: *State = @ptrCast(@alignCast(data orelse return err));
    const state: *State = @ptrCast(@alignCast(zathura.zathura_document_get_data(doc)));
    const surface = zathura.cairo_get_target(context);

    const index = zathura.zathura_page_get_index(page);

    const surface_width: usize = @intCast(zathura.cairo_image_surface_get_width(surface));
    const surface_height: usize = @intCast(zathura.cairo_image_surface_get_height(surface));

    const err = zathura.ZATHURA_ERROR_UNKNOWN;
    // just because of extremely high memory consumption.
    // zathura won't allow me to limit the zoom
    // it won't allow me to render just parts of image.
    // so i have to scale the entire thing to ridiculous sizes
    if (@max(surface_width, surface_height) > 10_000) {
        return err;
    }

    const image = zathura.cairo_image_surface_get_data(surface);
    state.render_to_buffer(
        index,
        image,
        surface_width,
        surface_height,
    ) catch |e| {
        std.debug.print("{?}\n", .{e});
        return err;
    };

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

// when does this even run??
fn plugin_page_render(page: ?*zathura.zathura_page_t, data: ?*anyopaque, _z_err: ?*zathura.zathura_error_t) callconv(.C) ?*zathura.zathura_image_buffer_t {
    _ = data;
    const z_err: *zathura.zathura_error_t = @ptrCast(_z_err);

    const doc = zathura.zathura_page_get_document(page);
    // const state: *State = @ptrCast(@alignCast(data orelse return err));
    const state: *State = @ptrCast(@alignCast(zathura.zathura_document_get_data(doc)));

    const index = zathura.zathura_page_get_index(page);

    const page_width: usize = @intFromFloat(zathura.zathura_page_get_width(page));
    const page_height: usize = @intFromFloat(zathura.zathura_page_get_height(page));

    const image: *zathura.zathura_image_buffer_t = zathura.zathura_image_buffer_create(@intCast(page_width), @intCast(page_height));
    state.render_to_buffer(
        index,
        image.data,
        page_width,
        page_height,
    ) catch |e| {
        std.debug.print("{?}\n", .{e});
        z_err.* = zathura.ZATHURA_ERROR_UNKNOWN;
        return null;
    };

    z_err.* = zathura.ZATHURA_ERROR_OK;
    return image;
}

const mime_types = [_][*c]const u8{
    "image/jpeg",
    "image/jpg",
    "image/png",
    "inode/directory",
    "image/avif",
    "image/heif",
    "image/bmp",
    "image/x-icns",
    "image/x-ico",
    "image/tiff",
    "image/x-webp",
    "image/webp",
};
export const zathura_plugin_5_6 = zathura.zathura_plugin_definition_t{
    .name = "zathura-images",
    .version = .{ .rev = 1, .minor = 0, .major = 0 },
    .mime_types = @constCast(mime_types[0..mime_types.len].ptr),
    .mime_types_size = mime_types.len,
    .functions = .{
        .document_open = &plugin_open,
        .document_free = &plugin_document_free,
        // .document_get_information = &plugin_get_information,
        .page_init = &plugin_page_init,
        .page_get_label = &plugin_page_label,
        // .page_clear = ,
        .page_render_cairo = &plugin_page_render_cairo,
        // .page_render = &plugin_page_render,
    },
};
