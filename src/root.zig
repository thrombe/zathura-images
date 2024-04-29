const std = @import("std");
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
        // .document_open = &plugin_open,
        // .document_free = ,
        // .document_get_information = &plugin_get_information,
        // .page_init = &plugin_page_init,
        // .page_clear = ,
        // .page_render_cairo = &plugin_page_render_cairo,
    },
};
