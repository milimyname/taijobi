// Cloudflare Workers bundle .wasm files as pre-compiled WebAssembly.Module
declare module "*.wasm" {
  const module: WebAssembly.Module;
  export default module;
}
