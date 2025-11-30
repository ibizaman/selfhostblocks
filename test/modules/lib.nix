{ lib, shb, ... }:
let
  inherit (lib) nameValuePair;
in
{
  # Tests that withReplacements can:
  # - recurse in attrs and lists
  # - .source field is understood
  # - .transform field is understood
  # - if .source field is found, ignores other fields
  testLibWithReplacements = {
    expected =
      let
        item = root: {
          a = "A";
          b = "%SECRET_${root}B%";
          c = "%SECRET_${root}C%";
        };
      in
      (item "")
      // {
        nestedAttr = item "NESTEDATTR_";
        nestedList = [ (item "NESTEDLIST_0_") ];
        doubleNestedList = [ { n = (item "DOUBLENESTEDLIST_0_N_"); } ];
      };
    expr =
      let
        item = {
          a = "A";
          b.source = "/path/B";
          b.transform = null;
          c.source = "/path/C";
          c.transform = v: "prefix-${v}-suffix";
          c.other = "other";
        };
      in
      shb.withReplacements (
        item
        // {
          nestedAttr = item;
          nestedList = [ item ];
          doubleNestedList = [ { n = item; } ];
        }
      );
  };

  testLibWithReplacementsRootList = {
    expected =
      let
        item = root: {
          a = "A";
          b = "%SECRET_${root}B%";
          c = "%SECRET_${root}C%";
        };
      in
      [
        (item "0_")
        (item "1_")
        [ (item "2_0_") ]
        [ { n = (item "3_0_N_"); } ]
      ];
    expr =
      let
        item = {
          a = "A";
          b.source = "/path/B";
          b.transform = null;
          c.source = "/path/C";
          c.transform = v: "prefix-${v}-suffix";
          c.other = "other";
        };
      in
      shb.withReplacements [
        item
        item
        [ item ]
        [ { n = item; } ]
      ];
  };

  testLibGetReplacements = {
    expected =
      let
        secrets = root: [
          (nameValuePair "%SECRET_${root}B%" "$(cat /path/B)")
          (nameValuePair "%SECRET_${root}C%" "prefix-$(cat /path/C)-suffix")
        ];
      in
      (secrets "")
      ++ (secrets "DOUBLENESTEDLIST_0_N_")
      ++ (secrets "NESTEDATTR_")
      ++ (secrets "NESTEDLIST_0_");
    expr =
      let
        item = {
          a = "A";
          b.source = "/path/B";
          b.transform = null;
          c.source = "/path/C";
          c.transform = v: "prefix-${v}-suffix";
          c.other = "other";
        };
      in
      map shb.genReplacement (
        shb.getReplacements (
          item
          // {
            nestedAttr = item;
            nestedList = [ item ];
            doubleNestedList = [ { n = item; } ];
          }
        )
      );
  };

  testParseXML = {
    expected = {
      "a" = {
        "b" = "1";
        "c" = {
          "d" = "1";
        };
      };
    };

    expr = shb.parseXML ''
      <a>
        <b>1</b>
        <c><d>1</d></c>
      </a>
    '';
  };
}
