import { Theme } from './Theme'

/**
 * ProviderIcon — styled text badge for LLM provider branding.
 * Matches OpenCode Desktop's provider-icons pattern.
 */
@Component
export struct ProviderIcon {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop providerId: string = ''
  @Prop iconSize: number = 20 // pixel size of the icon

  build() {
    Row() {
      Text(this.getAbbreviation())
        .fontSize(this.iconSize * 0.55)
        .fontWeight(FontWeight.Bold)
        .fontFamily(Theme.FONT_MONO)
        .fontColor(this.getTextColor())
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.getBgColor())
    .borderRadius(this.iconSize * 0.2)
    .borderWidth(1)
    .borderColor(this.getBorderColor())
  }

  private getAbbreviation(): string {
    const id = this.providerId.toLowerCase()
    if (id.indexOf('openai') >= 0) return 'AI'
    if (id.indexOf('anthropic') >= 0) return 'An'
    if (id.indexOf('google') >= 0 || id.indexOf('gemini') >= 0) return 'G'
    if (id.indexOf('mistral') >= 0) return 'Mi'
    if (id.indexOf('cohere') >= 0) return 'Co'
    if (id.indexOf('perplexity') >= 0) return 'Px'
    if (id.indexOf('groq') >= 0) return 'Gq'
    if (id.indexOf('deepseek') >= 0) return 'Ds'
    if (id.indexOf('openrouter') >= 0) return 'OR'
    if (id.indexOf('ollama') >= 0) return 'Ol'
    if (id.indexOf('azure') >= 0) return 'Az'
    if (id.indexOf('xai') >= 0 || id.indexOf('grok') >= 0) return 'xA'
    if (id.indexOf('together') >= 0) return 'Tg'
    if (id.indexOf('fireworks') >= 0) return 'Fw'
    if (id.indexOf('qwen') >= 0 || id.indexOf('alibaba') >= 0) return 'Qw'
    if (id.indexOf('zhipu') >= 0 || id.indexOf('glm') >= 0) return 'Zp'
    if (id.indexOf('moonshot') >= 0 || id.indexOf('kimi') >= 0) return 'Ms'
    if (id.indexOf('minimax') >= 0) return 'Mm'
    if (id.indexOf('bytedance') >= 0 || id.indexOf('doubao') >= 0) return 'Db'
    // Default: first 2 chars
    if (this.providerId.length >= 2) return this.providerId.substring(0, 2)
    return this.providerId
  }

  private getBgColor(): string {
    const id = this.providerId.toLowerCase()
    if (id.indexOf('openai') >= 0) return '#0a2e1a'
    if (id.indexOf('anthropic') >= 0) return '#2e1a0a'
    if (id.indexOf('google') >= 0 || id.indexOf('gemini') >= 0) return '#0a1a2e'
    if (id.indexOf('mistral') >= 0) return '#2e2e0a'
    if (id.indexOf('deepseek') >= 0) return '#0a1a2e'
    if (id.indexOf('groq') >= 0) return '#2e0a1a'
    if (id.indexOf('azure') >= 0) return '#0a1a3e'
    if (id.indexOf('xai') >= 0 || id.indexOf('grok') >= 0) return '#1a1a1a'
    if (id.indexOf('ollama') >= 0) return '#1a0a2e'
    if (id.indexOf('openrouter') >= 0) return '#1a2e2e'
    if (id.indexOf('qwen') >= 0 || id.indexOf('alibaba') >= 0) return '#1a0a3e'
    if (id.indexOf('zhipu') >= 0 || id.indexOf('glm') >= 0) return '#0a2e2e'
    if (id.indexOf('moonshot') >= 0 || id.indexOf('kimi') >= 0) return '#1a1a2e'
    return Theme.ACTIVE_BG
  }

  private getTextColor(): string {
    const id = this.providerId.toLowerCase()
    if (id.indexOf('openai') >= 0) return '#10b981'
    if (id.indexOf('anthropic') >= 0) return '#d97706'
    if (id.indexOf('google') >= 0 || id.indexOf('gemini') >= 0) return '#4285f4'
    if (id.indexOf('mistral') >= 0) return '#fbbf24'
    if (id.indexOf('deepseek') >= 0) return '#60a5fa'
    if (id.indexOf('groq') >= 0) return '#f472b6'
    if (id.indexOf('azure') >= 0) return '#60a5fa'
    if (id.indexOf('xai') >= 0 || id.indexOf('grok') >= 0) return '#e5e7eb'
    if (id.indexOf('ollama') >= 0) return '#a78bfa'
    if (id.indexOf('openrouter') >= 0) return '#67e8f9'
    if (id.indexOf('qwen') >= 0 || id.indexOf('alibaba') >= 0) return '#a78bfa'
    if (id.indexOf('zhipu') >= 0 || id.indexOf('glm') >= 0) return '#34d399'
    if (id.indexOf('moonshot') >= 0 || id.indexOf('kimi') >= 0) return '#818cf8'
    return Theme.TEXT_SECONDARY
  }

  private getBorderColor(): string {
    const id = this.providerId.toLowerCase()
    if (id.indexOf('openai') >= 0) return '#10b98140'
    if (id.indexOf('anthropic') >= 0) return '#d9770640'
    if (id.indexOf('google') >= 0 || id.indexOf('gemini') >= 0) return '#4285f440'
    if (id.indexOf('mistral') >= 0) return '#fbbf2440'
    if (id.indexOf('deepseek') >= 0) return '#60a5fa40'
    return Theme.BORDER
  }
}
