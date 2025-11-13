import { CodeBlockPreviewExtension } from '@blocksuite/affine/blocks/code';
import { SignalWatcher, WithDisposable } from '@blocksuite/affine/global/lit';
import type { CodeBlockModel } from '@blocksuite/affine/model';
import { unsafeCSSVarV2 } from '@blocksuite/affine/shared/theme';
import { ShadowlessElement } from '@blocksuite/std';
import { css, html, nothing, type PropertyValues } from 'lit';
import { property, state } from 'lit/decorators.js';
import { choose } from 'lit/directives/choose.js';
import { styleMap } from 'lit/directives/style-map.js';
import plantumlEncoder from 'plantuml-encoder';

export const CodeBlockPlantUMLPreview = CodeBlockPreviewExtension(
  'plantuml',
  model => html`<plantuml-preview .model=${model}></plantuml-preview>`
);

// PlantUML server options
const PLANTUML_SERVERS = [
  'https://www.plantuml.com/plantuml',
  'http://www.plantuml.com/plantuml',
  'https://plantuml.duckdns.org/plantuml',
];

export class PlantUMLPreview extends SignalWatcher(
  WithDisposable(ShadowlessElement)
) {
  static override styles = css`
    .plantuml-preview-loading {
      color: ${unsafeCSSVarV2('text/placeholder')};
      font-family: 'IBM Plex Mono';
      font-size: 12px;
      padding: 20px;
      text-align: center;
    }

    .plantuml-preview-error {
      color: ${unsafeCSSVarV2('button/error')};
      font-family: 'IBM Plex Mono';
      font-size: 12px;
      padding: 20px;
      text-align: center;
    }

    .plantuml-preview-container {
      width: 100%;
      min-height: 300px;
      border: 1px solid ${unsafeCSSVarV2('layer/insideBorder/border')};
      border-radius: 8px;
      background: ${unsafeCSSVarV2('layer/background/primary')};
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 16px;
      overflow: auto;
    }

    .plantuml-preview-container img {
      max-width: 100%;
      height: auto;
    }
  `;

  @property({ attribute: false })
  accessor model: CodeBlockModel | null = null;

  @state()
  accessor state: 'loading' | 'error' | 'finish' = 'loading';

  @state()
  accessor imageUrl: string = '';

  @state()
  accessor errorMessage: string = '';

  private renderTimeout: ReturnType<typeof setTimeout> | null = null;
  private readonly currentServer = PLANTUML_SERVERS[0];

  override firstUpdated(_changedProperties: PropertyValues): void {
    this._scheduleRender();

    if (this.model) {
      this.disposables.add(
        this.model.props.text$.subscribe(() => {
          this._scheduleRender();
        })
      );
    }
  }

  override willUpdate(changedProperties: PropertyValues<this>) {
    if (changedProperties.has('model')) {
      this._scheduleRender();
    }
  }

  override disconnectedCallback(): void {
    super.disconnectedCallback();
    if (this.renderTimeout) {
      clearTimeout(this.renderTimeout);
      this.renderTimeout = null;
    }
  }

  get normalizedPlantUMLCode() {
    return this.model?.props.text.toString() ?? '';
  }

  private _scheduleRender() {
    if (this.renderTimeout) {
      clearTimeout(this.renderTimeout);
    }

    this.renderTimeout = setTimeout(() => {
      this._render();
    }, 300);
  }

  private _render() {
    this.state = 'loading';

    const code = this.normalizedPlantUMLCode;
    if (!code || !code.trim()) {
      this.state = 'error';
      this.errorMessage = 'Empty PlantUML code';
      return;
    }

    try {
      // Encode PlantUML code
      const encoded = plantumlEncoder.encode(code);

      // Generate image URL (SVG format)
      this.imageUrl = `${this.currentServer}/svg/${encoded}`;

      // Preload image to detect errors
      const img = new Image();
      img.onload = () => {
        this.state = 'finish';
      };
      img.onerror = () => {
        this.state = 'error';
        this.errorMessage =
          'Failed to render PlantUML diagram. Please check syntax.';
      };
      img.src = this.imageUrl;
    } catch (error) {
      console.error('PlantUML encoding failed:', error);
      this.state = 'error';
      this.errorMessage = 'Failed to encode PlantUML code';
    }
  }

  override render() {
    return html`
      <div class="plantuml-preview-wrapper">
        ${choose(this.state, [
          [
            'loading',
            () =>
              html`<div class="plantuml-preview-loading">
                <div>Rendering PlantUML diagram...</div>
                <div style="font-size: 10px; opacity: 0.6; margin-top: 8px;">
                  Please wait
                </div>
              </div>`,
          ],
          [
            'error',
            () =>
              html`<div class="plantuml-preview-error">
                <div>${this.errorMessage}</div>
                <div style="font-size: 10px; opacity: 0.6; margin-top: 8px;">
                  Check your PlantUML syntax
                </div>
              </div>`,
          ],
        ])}
        <div
          class="plantuml-preview-container"
          style=${styleMap({
            display: this.state === 'finish' ? undefined : 'none',
          })}
        >
          ${this.state === 'finish'
            ? html`<img src=${this.imageUrl} alt="PlantUML diagram" />`
            : nothing}
        </div>
      </div>
    `;
  }
}

export function effects() {
  customElements.define('plantuml-preview', PlantUMLPreview);
}

declare global {
  interface HTMLElementTagNameMap {
    'plantuml-preview': PlantUMLPreview;
  }
}
