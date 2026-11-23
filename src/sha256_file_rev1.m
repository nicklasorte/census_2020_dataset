function hex = sha256_file_rev1(file_name)
%SHA256_FILE_REV1 SHA-256 hash of a file, as lowercase hex.
%   Base MATLAB has no file hash function; java.security.MessageDigest is
%   part of the JVM that ships with MATLAB. Reads in 64 MB chunks so that
%   large block files don't need to fit in memory.

arguments
    file_name (1,1) string {mustBeFile}
end

md = java.security.MessageDigest.getInstance("SHA-256");
fid = fopen(file_name, "r");
cleanup = onCleanup(@() fclose(fid));
chunk = 64 * 2^20;
while true
    data = fread(fid, chunk, "*uint8");
    if isempty(data)
        break
    end
    md.update(typecast(data, "int8"));
end
digest = typecast(int8(md.digest()), "uint8");
hex = lower(string(reshape(dec2hex(digest, 2)', 1, [])));
end
