import { CodeBlockConfigExtension } from '@blocksuite/affine/blocks/code';
import {
  type ViewExtensionContext,
  ViewExtensionProvider,
} from '@blocksuite/affine/ext-loader';
import { FrameworkProvider } from '@toeverything/infra';
import { bundledLanguagesInfo } from 'shiki';
import { z } from 'zod';

import {
  CodeBlockHtmlPreview,
  effects as htmlPreviewEffects,
} from './html-preview';
import {
  CodeBlockMermaidPreview,
  effects as mermaidPreviewEffects,
} from './mermaid-preview';
import {
  CodeBlockPlantUMLPreview,
  effects as plantumlPreviewEffects,
} from './plantuml-preview';

const optionsSchema = z.object({
  framework: z.instanceof(FrameworkProvider).optional(),
});

export class CodeBlockPreviewViewExtension extends ViewExtensionProvider {
  override name = 'code-block-preview';

  override schema = optionsSchema;

  override effect() {
    super.effect();

    htmlPreviewEffects();
    mermaidPreviewEffects();
    plantumlPreviewEffects();
  }

  override setup(
    context: ViewExtensionContext,
    options?: z.infer<typeof optionsSchema>
  ) {
    super.setup(context, options);

    // Register code block previews
    context.register(CodeBlockHtmlPreview);
    context.register(CodeBlockMermaidPreview);
    context.register(CodeBlockPlantUMLPreview);

    // Register custom languages (PlantUML, Mermaid, etc.) for all scopes
    if (context.scope === 'page' || context.scope === 'edgeless') {
      context.register(
        CodeBlockConfigExtension({
          langs: [
            ...bundledLanguagesInfo,
            // Add PlantUML as a custom language
            {
              id: 'plantuml',
              name: 'PlantUML',
              import: async () => ({}) as any, // No syntax highlighting needed
              aliases: ['puml'],
            },
            // Add Mermaid as a custom language
            {
              id: 'mermaid',
              name: 'Mermaid',
              import: async () => ({}) as any, // No syntax highlighting needed
              aliases: [],
            },
          ],
        })
      );
    }
  }
}
