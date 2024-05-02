const std = @import("std");

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

const mime_types = [_][*c]const u8{ "image/jpeg", "image/png" };
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
    _ = printing;
    _ = data; // nullptr??
    const doc = zathura.zathura_page_get_document(page);
    const surface = zathura.cairo_get_target(context);

    const surface_width: usize = @intCast(zathura.cairo_image_surface_get_width(surface));
    const surface_height: usize = @intCast(zathura.cairo_image_surface_get_height(surface));

    const image = zathura.cairo_image_surface_get_data(surface);

    const wand_o: *magick.MagickWand = @ptrCast(@alignCast(zathura.zathura_document_get_data(doc)));
    const wand = magick.CloneMagickWand(wand_o);
    defer _ = magick.DestroyMagickWand(wand);
    _ = magick.MagickResizeImage(wand, @intCast(surface_width), @intCast(surface_height), magick.TriangleFilter);
    const ret = magick.MagickExportImagePixels(wand, 0, 0, surface_width, surface_height, "BGRA", magick.CharPixel, image);
    if (ret == magick.MagickFalse) {
        return zathura.ZATHURA_ERROR_UNKNOWN;
    }

    return zathura.ZATHURA_ERROR_OK;
}

fn plugin_page_init(page: ?*zathura.zathura_page_t) callconv(.C) zathura.zathura_error_t {
    const doc = zathura.zathura_page_get_document(page);
    // _ = doc; // autofix
    const wand: *magick.MagickWand = @ptrCast(@alignCast(zathura.zathura_document_get_data(doc)));
    // const index = zathura.zathura_page_get_index(page);

    zathura.zathura_page_set_width(page, @floatFromInt(magick.MagickGetImageWidth(wand)));
    zathura.zathura_page_set_height(page, @floatFromInt(magick.MagickGetImageHeight(wand)));

    return zathura.ZATHURA_ERROR_OK;
}

fn plugin_open(doc: ?*zathura.zathura_document_t) callconv(.C) zathura.zathura_error_t {
    if (doc == null) {
        return zathura.ZATHURA_ERROR_UNKNOWN;
    }
    const p = zathura.zathura_document_get_path(doc);

    magick.MagickWandGenesis();
    const wand = magick.NewMagickWand();
    const stat = magick.MagickReadImage(wand, p);
    if (stat == magick.MagickFalse) {
        std.debug.print("can't do the magic wand thing", .{});
        return zathura.ZATHURA_ERROR_UNKNOWN;
    }
    zathura.zathura_document_set_data(doc, wand);

    zathura.zathura_document_set_number_of_pages(doc, 1);
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
