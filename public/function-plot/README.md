# function-plot vendor bundle

Pinned upstream: [function-plot 1.26.0](https://github.com/mauriciopoppe/function-plot/tree/v1.26.0)
(MIT). The bundle and bundled dependencies' licence notices live in `1.26.0/`.

This browser build exposes `window.functionPlot` and the interval arithmetic
already used by function-plot as `functionPlot.intervalMath`. The application
passes trusted numeric/interval callbacks; it never calls the library's expression
code generators with post content. No second plotting library is bundled.

Rebuild from this directory:

```sh
cd build
pnpm install --frozen-lockfile
pnpm build
```

`build/entry.js`, the pinned manifest and pnpm lockfile document the inputs.
`build/build.mjs` bundles the library and writes `THIRD-PARTY-LICENSES.txt` from
the packages actually included. Some upstream MIT packages omit their LICENSE
file from npm; the build preserves their published copyright notices with the MIT
licence text. esbuild's optional native binary is installed by pnpm; no postinstall
approval is required to run this build.

The current artifact is 228,019 bytes (68,442 bytes with gzip).
SHA-256 of `1.26.0/function-plot.js`:

```text
85a5b7eeb2827bfd3194c7f7684465b5dff5b48a8b432682b820dd4e5794009e
```

After dependency/build changes, regenerate the notices, update this checksum and
rerun the expression/interval tests and browser graph tests under Discourse's CSP.
