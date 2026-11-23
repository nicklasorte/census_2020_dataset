function shp_file = read_shapefile_zip_rev1(zip_file, unzip_folder)
%READ_SHAPEFILE_ZIP_REV1 Unzip a TIGER/Line archive once and return its .shp path.

arguments
    zip_file (1,1) string {mustBeFile}
    unzip_folder (1,1) string
end

[~, name] = fileparts(zip_file);
out_folder = fullfile(unzip_folder, name);
shp_file = fullfile(out_folder, name + ".shp");
if ~isfile(shp_file)
    unzip(zip_file, out_folder);
end
if ~isfile(shp_file)
    error("census:unzip", "No %s.shp inside %s", name, zip_file);
end
end
