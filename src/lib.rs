use zathura_plugin::*;
use std::fs;
use pango::LayoutExt;
use pango::FontDescription;

struct PluginType {
    markdown: String,
}

impl ZathuraPlugin for PluginType {
    type DocumentData = String;
    type PageData = ();

    fn document_open(doc: DocumentRef<'_>) -> Result<DocumentInfo<Self>, PluginError> {
        let path = doc.path_utf8();
        let markdown = match path {
            Ok(path) => fs::read_to_string(path).unwrap(),
            Err(_) => "".to_string(),
        };

        let doc = DocumentInfo {
            page_count: 1,
            plugin_data: markdown,
        };
        Ok(doc)
    }

    fn page_init(
        page: PageRef<'_>,
        doc_data: &mut Self::DocumentData,
    ) -> Result<PageInfo<Self>, PluginError> {
        let page = PageInfo {
            width: 600.0,
            height: 900.0,
            plugin_data: (),
        };
        Ok(page)
    }

    fn page_render(
        page: PageRef<'_>,
        doc_data: &mut Self::DocumentData,
        page_data: &mut Self::PageData,
        cairo: &mut cairo::Context,
        printing: bool,
    ) -> Result<(), PluginError> {
        Ok(())
    }
}

fn main() {
    println!("Hello, world!");
}


plugin_entry!("zathura-images", PluginType, ["text/markdown"]);
