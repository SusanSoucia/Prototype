declare module 'vue-markdown-shiki/dist/index.mjs' {
  import type { App, DefineComponent, Plugin } from 'vue';

  const VueMarkdownIt: DefineComponent<Record<string, unknown>, {}, any>;
  const VueMarkdownItProvider: DefineComponent<Record<string, unknown>, {}, any>;
  const VueMarkDownHeader: DefineComponent<Record<string, unknown>, {}, any>;

  const markdownPlugin: Plugin & {
    install: (app: App, options?: { theme?: string; defaultHighlightLang?: string }) => void;
  };

  export { VueMarkdownIt, VueMarkdownItProvider, VueMarkDownHeader };
  export default markdownPlugin;
}
