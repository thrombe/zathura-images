const std = @import("std");

const c_string = @cImport({
    @cInclude("string.h");
});
const magick = @cImport({
    // @cInclude("ImageMagick/MagickWand/magick-image.h");
    // @cInclude("ImageMagick/MagickCore/image.h");
    // @cInclude("MagickCore/MagickCore.h");
    @cDefine("MAGICKCORE_HDRI_ENABLE", "1");
    @cInclude("MagickWand/MagickWand.h");
});
// const zathura = struct {
//     const document = @cImport({
//         @cInclude("zathura/document.h");
//     });
//     const links = @cImport({
//         @cInclude("zathura/links.h");
//     });
//     const macros = @cImport({
//         @cInclude("zathura/macros.h");
//     });
//     const page = @cImport({
//         @cInclude("zathura/page.h");
//     });
//     const plugin_api = @cImport({
//         @cInclude("zathura/plugin-api.h");
//     });
//     const types = @cImport({
//         @cInclude("zathura/types.h");
//     });
//     const zathura_version = @cImport({
//         @cInclude("zathura/zathura-version.h");
//     });
// };
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
    _ = data; // autofix
    const doc = zathura.zathura_page_get_document(page);
    // _ = doc; // autofix
    const surface = zathura.cairo_get_target(context);

    const p_width_i: usize = @intCast(zathura.cairo_image_surface_get_width(surface));
    const p_height_i: usize = @intCast(zathura.cairo_image_surface_get_height(surface));
    const p_width: f64 = @floatFromInt(p_width_i);
    const p_height: f64 = @floatFromInt(p_height_i);
    const z_width = zathura.zathura_page_get_width(page);
    const z_height = zathura.zathura_page_get_height(page);

    const scalex: f64 = p_width / z_width;
    _ = scalex; // autofix
    const scaley: f64 = p_height / z_height;
    _ = scaley; // autofix

    // const rowstride = zathura.cairo_image_surface_get_stride(surface);
    const image = zathura.cairo_image_surface_get_data(surface);
    // _ = image; // autofix

    // const exc: ?*magick.ExceptionInfo = magick.AcquireExceptionInfo();
    // defer _ = magick.DestroyExceptionInfo(exc);
    // const img: *magick.Image = @ptrCast(@alignCast(zathura.zathura_document_get_data(doc)));
    // // const img2: *magick.Image = @ptrCast(magick.ResizeImage(img, @intCast(p_width_i), @intCast(p_height_i), magick.TriangleFilter, exc));
    // const img2: *magick.Image = @ptrCast(magick.InterpolativeResizeImage(img, @intCast(p_width_i), @intCast(p_height_i), magick.UndefinedInterpolatePixel, exc));
    // const img3: [*c]f32 = @ptrCast(magick.GetAuthenticPixels(img2, 0, 0, img2.columns, img2.rows, exc));

    // // std.debug.print("\n{d} {d} {d}\n", .{ img.columns, img.rows, 3 });
    // for (0..@intCast(p_width_i * p_height_i)) |i| {
    //     // const c = std.mem.asBytes(&img3[i]);
    //     // _ = c; // autofix
    //     // std.debug.print("{} {} {} {}\n", .{ c[0], c[1], c[2], c[3] });
    //     image[i * 4 + 0] = 0; // b
    //     image[i * 4 + 1] = 0; // g
    //     image[i * 4 + 2] = 200; // r
    //     image[i * 4 + 3] = 0; // a
    // }

    const wand_o: *magick.MagickWand = @ptrCast(@alignCast(zathura.zathura_document_get_data(doc)));
    const wand = magick.CloneMagickWand(wand_o);
    // _ = magick.MagickResizeImage(wand, @intCast(p_width_i), @intCast(p_height_i), magick.UndefinedFilter);
    _ = magick.MagickResizeImage(wand, @intCast(p_width_i), @intCast(p_height_i), magick.TriangleFilter);
    // _ = magick.MagickAdaptiveResizeImage(wand, p_width_i, p_height_i);

    const iter = magick.NewPixelIterator(wand);
    defer _ = magick.DestroyPixelIterator(iter);
    const height = magick.MagickGetImageHeight(wand);
    for (0..height) |y| {
        var width: usize = 0;
        var pixel: magick.PixelInfo = .{};
        const pixels = magick.PixelGetNextIteratorRow(iter, &width);
        for (0..width) |x| {
            magick.PixelGetMagickColor(pixels[x], &pixel);
            pixel.red /= 65535.0;
            pixel.blue /= 65535.0;
            pixel.green /= 65535.0;
            pixel.alpha /= 65535.0;
            pixel.red *= 255.0;
            pixel.blue *= 255.0;
            pixel.green *= 255.0;
            pixel.alpha *= 255.0;
            pixel.red = @max(0.0, pixel.red);
            pixel.blue = @max(0.0, pixel.blue);
            pixel.green = @max(0.0, pixel.green);
            pixel.alpha = @max(0.0, pixel.alpha);
            // std.debug.print("{d} {d} {d} {d} \n", .{ pixel.red, pixel.green, pixel.blue, pixel.alpha });
            image[(y * p_width_i + x) * 4 + 0] = @intFromFloat(pixel.blue); // b
            image[(y * p_width_i + x) * 4 + 1] = @intFromFloat(pixel.green); // g
            image[(y * p_width_i + x) * 4 + 2] = @intFromFloat(pixel.red); // r
            image[(y * p_width_i + x) * 4 + 3] = @intFromFloat(pixel.alpha); // a
        }
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
    // const iter = magick.NewPixelIterator(wand);
    // const height = magick.MagickGetImageHeight(wand);
    // for (0..height) |_| {
    //     var width: usize = 0;
    //     var pixel: magick.PixelInfo = .{};
    //     const pixels = magick.PixelGetNextIteratorRow(iter, &width);
    //     for (0..width) |x| {
    //         magick.PixelGetMagickColor(pixels[x], &pixel);
    //         // std.debug.print("{d} {d} {d} {d} \n", .{ pixel.red / 65535.0, pixel.green / 65535.0, pixel.blue / 65535.0, pixel.alpha / 65535.0 });
    //     }
    // }
    zathura.zathura_document_set_data(doc, wand);

    // const exc: ?*magick.ExceptionInfo = magick.AcquireExceptionInfo();
    // defer _ = magick.DestroyExceptionInfo(exc);
    // const info: ?*magick.ImageInfo = magick.CloneImageInfo(null);
    // if (info) |i| {
    //     _ = c_string.strcpy(i.filename[0..].ptr, p);
    // }
    // defer _ = magick.DestroyImageInfo(info);
    // const img: ?*magick.Image = magick.ReadImage(info, exc);
    // // defer _ = magick.DestroyImage(img);
    // zathura.zathura_document_set_data(doc, img);

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
