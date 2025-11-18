import type { ExtensionType } from '@blocksuite/store';

import { AttachmentBlockHtmlAdapterExtension } from './html.js';
import { AttachmentBlockMarkdownAdapterExtension } from './markdown.js';
import { AttachmentBlockNotionHtmlAdapterExtension } from './notion-html.js';

export const AttachmentBlockAdapterExtensions: ExtensionType[] = [
  AttachmentBlockNotionHtmlAdapterExtension,
  AttachmentBlockHtmlAdapterExtension,
  AttachmentBlockMarkdownAdapterExtension,
];
