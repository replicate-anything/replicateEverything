# Presence-probe spec for a declared SSC package name

Most SSC packages install a runnable ado command that `which` can probe
directly. A few ship no command at all - notably `moremata`, which is a
pure Mata function library (`lmoremata.mlib` + help files, no
`moremata.ado`). `which moremata` therefore always returns "command not
found" (`r(111)`) even when the package is correctly installed via
`ssc install moremata`, which is exactly what makes the auto-generated
dependency probe report a false "missing" for otherwise-installed
packages. For those, probe the installed library/help file directly with
`findfile` instead.

## Usage

``` r
stata_package_probe_spec(pkg)
```

## Arguments

- pkg:

  Declared package name from `stata_packages:`.

## Value

List with `kind` (`"command"` or `"file"`) and `target` (command name,
or filename to `findfile`).
