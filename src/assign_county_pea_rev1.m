function pea_num = assign_county_pea_rev1(county_fips, pea_counties, county_changes)
%ASSIGN_COUNTY_PEA_REV1 PEA number for each current county FIPS code.
%   pea_num = assign_county_pea_rev1(county_fips, pea_counties, county_changes)
%
%   PEAs are aggregations of counties (47 CFR Part 27, Appendix A to
%   Subpart A). Counties created or renamed after the 2010-based list are
%   first mapped with county_changes. Raises an error if any county is
%   unmapped, so a future county change can't silently drop population.

arguments
    county_fips (:,1) string
    pea_counties table
    county_changes table
end

lookup_fips = county_fips;
[tf_chg, loc_chg] = ismember(lookup_fips, county_changes.current_county_fips);
lookup_fips(tf_chg) = county_changes.cfr_county_fips(loc_chg(tf_chg));
[tf, loc] = ismember(lookup_fips, pea_counties.FIPS);
if ~all(tf)
    missing = unique(county_fips(~tf));
    error("census:pea", "Counties with no PEA (add them to county_fips_changes.csv): %s", strjoin(missing, ", "));
end
pea_num = pea_counties.PEA_Num(loc);
end
