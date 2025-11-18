import { AttachmentBlockSchema } from '@blocksuite/affine-model';
import {
  BlockHtmlAdapterExtension,
  type BlockHtmlAdapterMatcher,
} from '@blocksuite/affine-shared/adapters';
import { getAssetName } from '@blocksuite/store';

export const attachmentBlockHtmlAdapterMatcher: BlockHtmlAdapterMatcher = {
  flavour: AttachmentBlockSchema.model.flavour,
  // No direct HTML-to-block mapping here for attachments
  toMatch: () => false,
  fromMatch: o => o.node.flavour === AttachmentBlockSchema.model.flavour,
  fromBlockSnapshot: {
    enter: async (o, context) => {
      const { assets, walkerContext, updateAssetIds } = context;
      const blobId = (o.node.props?.sourceId ?? '') as string;
      if (!assets || !blobId) return;

      await assets.readFromBlob(blobId);
      const blob = assets.getAssets().get(blobId);
      if (!blob) return;

      const blobName = getAssetName(assets.getAssets(), blobId);
      const displayName = (blob as File).name ?? blobName;
      updateAssetIds?.(blobId);

      // Render as a simple anchor link to the asset
      walkerContext
        .openNode(
          {
            type: 'element',
            tagName: 'p',
            properties: {},
            children: [],
          },
          'children'
        )
        .openNode(
          {
            type: 'element',
            tagName: 'a',
            properties: {
              href: `assets/${blobName}`,
              download: displayName,
            },
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
        .closeNode() // a
        .closeNode(); // p
    },
  },
};

export const AttachmentBlockHtmlAdapterExtension = BlockHtmlAdapterExtension(
  attachmentBlockHtmlAdapterMatcher
);
