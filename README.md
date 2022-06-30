# Rust Component Boilerplate

## Building

The Makefile includes the recipes necessary to generate code from the Apex schemas in ./schemas/.

To codegen, build, and sign your WASM module, run `make`

```shell
$ make
```

## Codegen and clean

```shell
$ make clean && make codegen
```

## Testing

```shell
$ make test
```
