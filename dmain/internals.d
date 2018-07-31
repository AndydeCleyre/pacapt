/*
  Purpose : just for fun
  Author  : Ky-Anh Huynh
  Date    : 2018 07 27
  License : MIT
*/

module pacapt.internals;

auto issue2pacman() {
  debug import std.stdio;
  debug import std.format;
  import std.file;
  import std.string: indexOf;
  import std.process: execute;

  auto pacman = "unknown";

  auto uname = "uname".execute.output;
  if (uname == "SunOS") {
    pacman = "sun_tools";
    debug stderr.writefln("(debug) quickly pkg found from uname: %s", pacman);
    return pacman;
  }

  auto const matches = [
    "Arch Linux"      : "pacman",
    "Debian GNU/Linux": "dpkg",
    "Ubuntu"          : "dpkg",
    "Exherbo Linux"   : "cave",
    "CentOS"          : "yum",
    "Red Hat"         : "yum",
    "SUSE"            : "zypper",
    "OpenBSD"         : "pkg_tools",
    "Bitrig"          : "pkg_tools",
    "Alpine Linux"    : "apk",
    "SunOS"           : "sun_tools",
  ];

  auto const fname_issue = "/etc/issue";
  auto const fname_os_release = "/etc/os-release";

  auto text = "";

  if (fname_issue.exists) {
    text ~= fname_issue.readText;
  }
  if (fname_os_release.exists) {
    text ~= "\n";
    text ~= fname_os_release.readText;
  }

  foreach (m, pkg; matches) {
    if (text.indexOf(m) > -1) {
      pacman = pkg;
      break;
    }
  }

  if (pacman != "unknown") {
    debug stderr.writefln("(debug) pkg found from issue file(s): %s", pacman);
    return pacman;
  }

  // Loop detection
  auto const standard_pacman = "/usr/bin/pacman";
  if (standard_pacman.isExecutable && (thisExePath != standard_pacman)) {
    pacman = "pacman";
    debug stderr.writefln("(debug) possibly found standard pacman: %s", standard_pacman);
    return pacman;
  }

  auto const executable_checks = [
    "/data/data/com.termux/files/usr/bin/apt-get" : "dpkg",
    "/usr/bin/apt-get"    : "dpkg",
    "/usr/bin/cave"       : "cave",
    "/usr/bin/dnf"        : "dnf",
    "/usr/bin/yum"        : "yum",
    "/opt/local/bin/port" : "macports",
    "/usr/bin/emerge"     : "portage",
    "/usr/bin/zypper"     : "zypper",
    "/usr/sbin/pkg"       : "pkgng",
    "/usr/sbin/pkgadd"    : "sun_tools",
    "/sbin/apk"           : "apk",
    "/usr/bin/tazpkg"     : "tazpkg",
    "/usr/bin/swupd"      : "swupd",
  ];


  foreach (path, pkg; executable_checks) {
    if (path.isExecutable) {
      pacman = pkg;
      break;
    }
  }

  if (pacman != "unknown") {
    debug stderr.writefln("(debug) pkg from executable file: %s", pacman);
    return pacman;
  }

  // make sure pkg_add is after pkgng, FreeBSD base comes with it until converted
  if ("/usr/sbin/pkg_add".isExecutable) {
    debug stderr.writefln("(debug) FreeBSD pkg_add found");
    pacman = "pkg_tools";
    return pacman;
  }

  import std.process: executeShell;
  auto brew_status = "command -v brew >/dev/null".executeShell.status;
  if (brew_status == 0) {
    debug stderr.writefln("(debug) Found homebrew in search path");
    pacman = "homebrew";
    return pacman;
  }

  // We give up now.
  return pacman;
}

auto isExecutable(in string path) {
  import std.file: getAttributes, exists;
  import std.conv: octal;
  auto mode = path.exists ? path.getAttributes() : 0;
  auto const exec_mode = octal!100; /* 00100, S_IXUSR, S_IEXEC*/
  return mode & exec_mode ? true : false;
}

unittest {
  auto a10 = "/usr/bin/chmod".isExecutable;
  auto a11 = "/sbin/chmod".isExecutable;
  auto b10 = "/usr/non/existent".isExecutable;
  assert(a10 || a11, "chmod is executable and found from /usr/bin/ or /sbin");
  assert(! b10, "Non existent file should not be executable");
}

auto programName2pacman(in string path = "") {
  import std.file: thisExePath;
  import std.path: baseName, stripExtension;
  import std.string: split, indexOf;

  auto base_name = (path == "" ? thisExePath : path).baseName.stripExtension;
  auto names = base_name.split("-");
  auto pacman = "unknown";

  if (names.length > 1) {
    auto last_name = names[$-1];
    pacman = last_name;
  }

  return pacman;
}

unittest {
  auto p1 = programName2pacman("/usr/bin/pacman-foobar");
  auto p2 = programName2pacman("/usr/bin/pacman-conda");
  auto p3 = programName2pacman("/usr/bin/pacman.conda");
  assert(p1 == "foobar", "pacman-foobar should return unknown pacman [foobar]");
  assert(p2 == "conda", "pacman-conda should return conda pacman");
  assert(p3 == "unknown", "pacman.conda with dot splitter is not supported");
}

auto warning(in string text) {
  import std.stdio;
  stderr.writeln(":: Warning: " ~ text);
}

auto error(in string text) {
  import std.stdio;
  stderr.writeln(":: Error: " ~ text);
  throw new Exception(":: Error: " ~ text);
}

unittest {
  import std.exception: assertThrown, assertNotThrown;
  assertNotThrown("This is a test warning.".warning);
  assertThrown("This is an error message.".error);
}

version(unittest) {
  auto _m(string[] args) {
    auto _r = args.pacmanOptions.pacmanMethod;
    debug(2) {
      import std.stdio, std.format;
      writefln("Found method: %s", _r);
    }
    return _r;
  }
}

unittest {
  assert("dpkg_Rs" == ["test-dpkg", "-Rs"]._m);
  assert("dpkg_Rs" == ["test-dpkg", "-Rss"]._m);
  assert("dpkg_Rs" == ["test-dpkg", "-Rsw"]._m);
  assert("dpkg_Rqs" == ["test-dpkg", "-Rqsw"]._m);
  assert("dpkg_Rqsy" == ["test-dpkg", "-Rqsw", "-y", "-v"]._m);
  assert("dpkg_Suy" == ["test-dpkg", "-S", "-u", "-yyyyy"]._m);
  assert("dpkg_Suy" == ["test-dpkg", "-S", "-yyyyy", "-uuu"]._m);
  assert("dpkg_Scccy" == ["test-dpkg", "-S", "-yyyyy", "-cccccc"]._m);
  assert("dpkg_Sccc" == ["test-dpkg", "-S", "-w", "-cccccc"]._m);
  assert("dpkg_Sci" == ["test-dpkg", "-S", "-i", "-c"]._m);
}

struct pacmanOptions {
  bool
    verbose = false,        /* -v */
    download_only = false,  /* -w */
    no_confirm = false,     /* --noconfirm */
    show_version = false,   /* -V */
    list_ops = false,       /* -P */
    help_wanted = false,

    quiet_mode = false,     /* -q */
    upgrades = false,       /* -u */
    refresh = false,        /* -y */
    result = true
    ;

  uint
    pQ = 0,
    pR = 0,
    pS = 0,
    pU = 0,
    ss = 0,
    sl = 0,
    si = 0,
    sp = 0,
    so = 0,
    sm = 0,
    sn = 0,
    clean = 0 /* -c */
    ;

  string[] args0;
  string[] remained;
  string pacman;


  auto pacmanMethod() {
    import std.format: format;
    auto method = "";

    method ~= pacman;

    method ~= "_";

    /* QRSU */
    method ~= pQ ? "Q" : "";
    method ~= pR ? "R" : "";
    method ~= pS ? "S" : "";
    method ~= pU ? "U" : "";

    /* cilmnop[q]s[u][v-w-][y] */

    method ~= (clean >= 3 ? "ccc" : clean == 2 ? "cc" : clean == 1 ? "c" : "");
    method ~= (si >= 2 ? "ii" : si == 1 ? "i" : "");
    method ~= (sl >= 1 ? "l" : "");
    method ~= (sm >= 1 ? "m" : "");
    method ~= (sn >= 1 ? "n" : "");
    method ~= (so >= 1 ? "o" : "");
    method ~= (sp >= 1 ? "p" : "");
    method ~= (quiet_mode ? "q" : "");
    method ~= (ss >= 1 ? "s" : "");
    method ~= (upgrades ? "u" : "");
    method ~= (refresh ? "y" : "");

    return method;
  }

  /*
    FIXME: This would be part of the help message.

    An overview of options from the stable pacapt script

      -h --help                 Help
      --noconfirm --no-confirm  No confirmation [Need translation]
      --                        Termination
      -V                        pacapt version
      -P                        List of supported operations
      -Q R S U  (+)             Primary action
      -s l i p o m n (+)        Secondary action
      -q                        Third option
      -u                        Converted to uy or u
      -y                        Same as above
      -c (+)                    Clean (c, cc, ccc)
      -w                        Download only [Need translation]
      -v                        Verbose [Need translation]
  */
  this(string[] args) {
    import std.getopt;

    auto getopt_results = getopt(args,
      std.getopt.config.caseSensitive,
      std.getopt.config.bundling,
      std.getopt.config.passThrough,
      "query|Q+", "Query", &pQ,
      "remove|R+", "Remove", &pR,
      "sync|S+", "Sync", &pS,
      "upgrade|U+", "Upgrade", &pU,
      "search|s+", "Search", &ss,
      "recursive+", "Recursive option used with --remove. Short version: -s", &ss,
      "list|l+", "listing option", &sl,
      "info|i+", &si,
      "file|p+", &sp,
      "owns|o+", &so,
      "foreign|m+", &sm,
      "n|nosave|native+", &sn,
      "verbose|v", "Be verbose", &verbose,
      "download-only|w", "Download without installing", &download_only,
      "version|V", "Show pacapt version", &show_version,
      "P", "Print list of supported options", &list_ops,
      "quiet|q", "Be quiet in some operation", &quiet_mode,
      "upgrades|u", &upgrades,
      "refresh|y", "Refresh local package database", &refresh,
      "noconfirm", "Assume yes to all questions", &no_confirm,
      "no-confirm", "Assume yes to all questions", &no_confirm,
      "clean|c+", "Clean packages.", &clean,
    );

    args0 = args[0..1];
    remained = args[1..$];

    pacman = programName2pacman(args0.length > 0 ? args0[0] : "");
    if (pacman == "unknown") {
      pacman = issue2pacman;
    }

    if (getopt_results.helpWanted) {
      help_wanted = true;
      defaultGetoptPrinter("List of options:", getopt_results.options);
      result = false;
    }

    // FIXME: We should passthrough option
    if (pQ + pR + pS + pU != 1) {
      "Primary option (Q R S U) must be specified at most once.".warning;
      result = false;
    }

    if (download_only) {
      auto tx_download_only = translateWoption(pacman);
      args0 ~= tx_download_only;
      result &= (tx_download_only.length > 0);
    }

    if (verbose) {
      auto tx_verbose = translateDebugOption(pacman);
      args0 ~= tx_verbose;
      result &= (tx_verbose.length > 0);
    }

    if (no_confirm) {
      auto tx_no_confirm = translateNoConfirmOption(pacman);
      args0 ~= tx_no_confirm;
      result &= (tx_no_confirm.length > 0);
    }

    debug(2) {
      import std.stdio, std.format;
      stderr.writefln(
  "
  (debug)
    Query         : %d
    Remove        : %d
    Sync          : %d
    Upgrade       : %d
    s             : %d
    l             : %d
    i             : %d
    p             : %d
    o             : %d
    m             : %d
    n             : %d
    download only : %b
    no confirm    : %b
    show version  : %b
    print ops     : %b
    quiet mode    : %b
    upgrades      : %b
    refresh       : %b
    args0         : %(%s, %)
    remains       : %(%s, %)
    pacman        : %s
  ",
        pQ, pR, pS, pU,
        ss, sl, si, sp, so, sm, sn,
        download_only, no_confirm, show_version, list_ops,
        quiet_mode, upgrades, refresh,
        args0, remained, pacman,
      );
    }
  }
}

unittest {
  import std.format;

  auto p1 = pacmanOptions(["pacman", "-R", "-U"]);
  assert(! p1.result, "Multiple primary action -RU is rejected.");

  auto p2 = pacmanOptions(["pacman", "-i", "-s"]);
  assert(! p2.result, "Primary action must be specified.");

  auto primary_actions = ["R", "S", "Q", "U"];
  foreach (p; primary_actions) {
    auto px = pacmanOptions(["pacman", "-" ~ p]);
    assert(px.result, "At least on primary action (%s) is acceptable.".format(p));
    auto py = pacmanOptions(["pacman", "-" ~ p ~ p]);
    assert(! py.result, "Multiple primary action (%s) is not acceptable.".format(p));
  }

  auto p3 = pacmanOptions(["/usr/bin/pacman", "-R", "-s", "-h"]);
  assert(! p3.result, "Help query should return false");
  assert(p3.pacman == "pacman", "Found pacman package manager.");

  auto p4 = pacmanOptions(["pacman", "-R", "--", "-R"]);
  assert(p4.result, "Termination (--) is working fine.");

  auto p5 = pacmanOptions(["pacman", "-S", "-cc", "-c"]);
  assert(p5.result && (p5.clean >= 3), "-Sccc (%d) bundling is working fine".format(p5.clean));

  auto p6 = pacmanOptions(["/usr/bin/pacapt-tazpkg", "-Suw"]);
  assert(p6.result == false, "tarzpkg does not support -w.");
  assert(p6.pacman == "tazpkg", "Found correct pacman: tazpkg");

  auto p7 = pacmanOptions(["/usr/local/bin/pacapt-macports", "-Suwv"]);
  assert(p7.result, "macports supports -w.");
  assert(p7.pacman == "macports", "Should found macports");
  assert(p7.args0[1] == "fetch", "macports injects custom options [%(%s, %), %(%s, %)]".format(p7.args0, p7.remained));
}

auto translateWoption(in string pacman) {
  auto const translations = [
    "pacman": "-w",
    "dpkg": "-d",
    "dave": "-f",
    "macports": "fetch",
    "portage": "--fetchonly",
    "zypper": "--download-only",
    "pkgng": "fetch",
    "yum": "--downloadonly", /* FIXME: require package 'yum-downloadonly' */
    "apk": "fetch",
  ];

  if (pacman == "tazpkg") {
    "Please use tazpkg get ... to download and save packages".warning;
  }

  string[] result = [];
  foreach (k,v; translations) {
    if (pacman == k) {
      result ~= v;
      break;
    }
  }

  return result;
}

unittest {
  assert(translateWoption("tazpkg") == []);
  assert(translateWoption("pkgng") == ["fetch"]);
  assert(translateWoption("foobar") == []);
}

// FIXME: Update environment DEBIAN_FRONTEND=noninteractive
// FIXME: There is also --force-yes for a stronger case
auto translateNoConfirmOption(in string pacman) {
  auto const translations = [
    "pacman": "--noconfirm",
    "dpkg": "--yes",
    "dnf": "--assumeyes",
    "yum": "--assumeyes",
    "zypper": "--no-confirm",
    "pkgng": "-y",
    "tazpkg": "--auto",
  ];

  string[] result = [];
  foreach (k,v; translations) {
    if (pacman == k) {
      result ~= v;
      break;
    }
  }

  return result;
}

unittest {
  assert(translateNoConfirmOption("foobar") == []);
}

auto translateDebugOption(in string pacman, in string opt = "-v") {
  string[] result = [];
  if (pacman == "tazpkg") {
    "Debug option (-v) is not supported by tazpkg".warning;
  }
  else {
    result ~= opt;
  }
  return result;
}

unittest {
  assert(translateDebugOption("tazpkg") == []);
  assert(translateDebugOption("pacman") != []);
}
