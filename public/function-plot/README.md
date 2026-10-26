# function-plot

`1.26.0/function-plot.js` is the unmodified browser distribution from
`npm pack function-plot@1.26.0` (`dist/function-plot.js`).

- Upstream: https://github.com/mauriciopoppe/function-plot
- License: MIT; see `1.26.0/LICENSE`.
- SHA-256: `2c4a888fc382fe9102141f3c3e15094c4d1595385e2eb074507c01cd91307c70`.

The renderer supplies callbacks from the restricted maths interpreter, using the
built-in numeric sampler. It does not invoke upstream's string-to-JavaScript
compiler or require `unsafe-eval`. The library draws SVG curves, axes and zoom
behaviour locally; no graph contents are sent to an external rendering service.

When updating the library, preserve its license, update the pinned asset path and
checksum, and verify actual rendering under Discourse's default CSP. Check cleanup
of the upstream chart cache when decorated content is replaced.
