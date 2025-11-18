import {
  AttachmentBlockSchema,
  FootNoteReferenceParamsSchema,
} from '@blocksuite/affine-model';
import {
  BlockMarkdownAdapterExtension,
  type BlockMarkdownAdapterMatcher,
  FOOTNOTE_DEFINITION_PREFIX,
  FULL_FILE_PATH_KEY,
  getFootnoteDefinitionText,
  getImageFullPath,
  isFootnoteDefinitionNode,
  type MarkdownAST,
} from '@blocksuite/affine-shared/adapters';
import { getAssetName, nanoid, type NodeProps } from '@blocksuite/store';

const isAttachmentFootnoteDefinitionNode = (node: MarkdownAST) => {
  if (!isFootnoteDefinitionNode(node)) return false;
  const footnoteDefinition = getFootnoteDefinitionText(node);
  try {
    const footnoteDefinitionJson = FootNoteReferenceParamsSchema.parse(
      JSON.parse(footnoteDefinition)
    );
    return (
      footnoteDefinitionJson.type === 'attachment' &&
      !!footnoteDefinitionJson.blobId
    );
  } catch {
    return false;
  }
};

const isMarkdownLinkNode = (node: MarkdownAST): node is any =>
  (node as any)?.type === 'link' && typeof (node as any).url === 'string';

function isLocalAssetLink(url: string) {
  const lower = url.toLowerCase();
  if (
    lower.startsWith('http:') ||
    lower.startsWith('https:') ||
    lower.startsWith('data:') ||
    lower.startsWith('mailto:') ||
    lower.startsWith('#')
  ) {
    return false;
  }
  return true;
}

function isImageExt(url: string) {
  const ext = url.split('.').pop()?.toLowerCase() ?? '';
  return ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp', 'avif'].includes(
    ext
  );
}

function clearMarkdownLinkNode(linkNode: any) {
  linkNode.type = 'text';
  linkNode.value = '';
  if (Array.isArray(linkNode.children)) {
    linkNode.children = [];
  }
  if ('url' in linkNode) {
    linkNode.url = '';
  }
  if ('title' in linkNode) {
    linkNode.title = '';
  }
}

async function processAttachmentLinkToBlock(
  nodeProps: NodeProps<MarkdownAST>,
  context: Parameters<
    NonNullable<BlockMarkdownAdapterMatcher['toBlockSnapshot']['enter']>
  >[1]
) {
  const linkNode = nodeProps.node as any;
  const linkUrl = typeof linkNode.url === 'string' ? linkNode.url : '';
  const { assets, walkerContext, configs } = context;
  if (!assets || !linkUrl) return;

  let blobId = '';
  const fullFilePath = configs.get(FULL_FILE_PATH_KEY);
  if (fullFilePath) {
    const fullPath = getImageFullPath(fullFilePath, linkUrl);
    blobId = assets.getPathBlobIdMap().get(fullPath) ?? '';
  } else {
    // Fallback: try progressively trimming leading segments
    const parts = linkUrl.split('/');
    while (parts.length > 0) {
      const key = assets
        .getPathBlobIdMap()
        .get(decodeURIComponent(parts.join('/')));
      if (key) {
        blobId = key;
        break;
      }
      parts.shift();
    }
  }

  if (!blobId) return;
  // Ensure asset is loaded and accessible
  await assets.readFromBlob(blobId);
  const file = assets.getAssets().get(blobId) as File | undefined;
  const blobName = getAssetName(assets.getAssets(), blobId);
  const linkText = Array.isArray(linkNode?.children)
    ? linkNode.children
        .map((n: any) => (n && typeof n.value === 'string' ? n.value : ''))
        .join('')
        .trim()
    : '';
  const displayName = linkText || (file?.name ?? blobName);
  const size = (file?.size as number | undefined) ?? 0;
  const type = (file?.type as string | undefined) ?? 'application/octet-stream';

  walkerContext
    .openNode(
      {
        type: 'block',
        id: nanoid(),
        flavour: AttachmentBlockSchema.model.flavour,
        props: {
          name: displayName,
          sourceId: blobId,
          size,
          type,
          // let other props use schema defaults
        },
        children: [],
      },
      'children'
    )
    .closeNode();
  walkerContext.skipAllChildren();
  clearMarkdownLinkNode(linkNode);
}

export const attachmentBlockMarkdownAdapterMatcher: BlockMarkdownAdapterMatcher =
  {
    flavour: AttachmentBlockSchema.model.flavour,
    toMatch: o =>
      isAttachmentFootnoteDefinitionNode(o.node) ||
      (isMarkdownLinkNode(o.node) &&
        isLocalAssetLink((o.node as any).url) &&
        !isImageExt((o.node as any).url)),
    fromMatch: o => o.node.flavour === AttachmentBlockSchema.model.flavour,
    toBlockSnapshot: {
      enter: async (o, context) => {
        // Case 1: Footnote-definition based attachment reference
        if (!isFootnoteDefinitionNode(o.node)) {
          // Case 2: Markdown link pointing to a local asset -> treat as attachment
          if (isMarkdownLinkNode(o.node)) {
            await processAttachmentLinkToBlock(
              o as NodeProps<MarkdownAST>,
              context
            );
          }
          return;
        }

        const { walkerContext, configs } = context;
        const footnoteIdentifier = o.node.identifier;
        const footnoteDefinitionKey = `${FOOTNOTE_DEFINITION_PREFIX}${footnoteIdentifier}`;
        const footnoteDefinition = configs.get(footnoteDefinitionKey);
        if (!footnoteDefinition) {
          return;
        }
        try {
          const footnoteDefinitionJson = FootNoteReferenceParamsSchema.parse(
            JSON.parse(footnoteDefinition)
          );
          const { blobId, fileName } = footnoteDefinitionJson;
          if (!blobId || !fileName) {
            return;
          }
          walkerContext
            .openNode(
              {
                type: 'block',
                id: nanoid(),
                flavour: AttachmentBlockSchema.model.flavour,
                props: {
                  name: fileName,
                  sourceId: blobId,
                  footnoteIdentifier,
                  style: 'citation',
                },
                children: [],
              },
              'children'
            )
            .closeNode();
          walkerContext.skipAllChildren();
        } catch (err) {
          console.warn('Failed to parse attachment footnote definition:', err);
          return;
        }
      },
    },
    fromBlockSnapshot: {
      // Export attachment block to a markdown link that points to the assets folder
      enter: async (o, context) => {
        const { assets, walkerContext, updateAssetIds } = context;
        const blobId = (o.node.props?.sourceId ?? '') as string;
        if (!assets || !blobId) return;

        // Ensure the asset is loaded and retrievable
        await assets.readFromBlob(blobId);
        const blob = assets.getAssets().get(blobId);
        if (!blob) return;

        const blobName = getAssetName(assets.getAssets(), blobId);
        updateAssetIds?.(blobId);

        const originalName = (o.node.props?.name as string | undefined) ?? '';
        const displayName = originalName || ((blob as File).name ?? blobName);

        // paragraph > link[text]
        walkerContext
          .openNode(
            {
              type: 'paragraph',
              children: [],
            },
            'children'
          )
          .openNode(
            {
              type: 'link',
              url: `assets/${blobName}`,
              title: null,
              children: [],
            },
            'children'
          )
          .openNode(
            {
              type: 'text',
              value: displayName,
            },
            'children'
          )
          .closeNode() // text
          .closeNode() // link
          .closeNode(); // paragraph
      },
    },
  };

export const AttachmentBlockMarkdownAdapterExtension =
  BlockMarkdownAdapterExtension(attachmentBlockMarkdownAdapterMatcher);
