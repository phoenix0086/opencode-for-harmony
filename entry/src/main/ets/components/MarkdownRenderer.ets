import { Theme } from './Theme'

/**
 * Markdown block segment types for parsed content.
 */
export class MdSegment {
  type: string = '' // 'paragraph' | 'heading' | 'codeBlock' | 'list' | 'blockquote' | 'hr' | 'empty'
  text: string = ''
  language: string = ''
  level: number = 1
  items: string[] = []
  ordered: boolean = false
}

/**
 * Inline span for styled text within a paragraph.
 */
export class InlineSpan {
  text: string = ''
  bold: boolean = false
  italic: boolean = false
  code: boolean = false
  link: string = ''
}

/**
 * Lightweight Markdown parser for OpenCode agent messages.
 * Supports: headings, bold, italic, code blocks, inline code, links, lists, blockquotes, hr.
 */
export class MarkdownParser {
  static parse(input: string): MdSegment[] {
    if (input.length === 0) return []
    const segments: MdSegment[] = []
    const lines: string[] = input.split('\n')
    let i = 0

    while (i < lines.length) {
      const line = lines[i]

      // Fenced code block
      if (line.startsWith('```')) {
        const lang = line.substring(3).trim()
        const codeLines: string[] = []
        i += 1
        while (i < lines.length && !lines[i].startsWith('```')) {
          codeLines.push(lines[i])
          i += 1
        }
        i += 1 // skip closing ```
        const seg = new MdSegment()
        seg.type = 'codeBlock'
        seg.language = lang
        seg.text = codeLines.join('\n')
        segments.push(seg)
        continue
      }

      // Heading
      if (line.startsWith('#')) {
        let level = 0
        let j = 0
        while (j < line.length && line.charAt(j) === '#') {
          level += 1
          j += 1
        }
        if (level > 6) level = 6
        const seg = new MdSegment()
        seg.type = 'heading'
        seg.level = level
        seg.text = line.substring(level).trim()
        segments.push(seg)
        i += 1
        continue
      }

      // Horizontal rule
      if (line.trim() === '---' || line.trim() === '***' || line.trim() === '___') {
        const seg = new MdSegment()
        seg.type = 'hr'
        segments.push(seg)
        i += 1
        continue
      }

      // Blockquote
      if (line.startsWith('>')) {
        const quoteLines: string[] = []
        while (i < lines.length && lines[i].startsWith('>')) {
          quoteLines.push(lines[i].substring(1).trim())
          i += 1
        }
        const seg = new MdSegment()
        seg.type = 'blockquote'
        seg.text = quoteLines.join(' ')
        segments.push(seg)
        continue
      }

      // Unordered list
      if (line.match(/^\s*[-*+]\s/)) {
        const items: string[] = []
        while (i < lines.length && lines[i].match(/^\s*[-*+]\s/)) {
          items.push(lines[i].replace(/^\s*[-*+]\s/, ''))
          i += 1
        }
        const seg = new MdSegment()
        seg.type = 'list'
        seg.ordered = false
        seg.items = items
        segments.push(seg)
        continue
      }

      // Ordered list
      if (line.match(/^\s*\d+\.\s/)) {
        const items: string[] = []
        while (i < lines.length && lines[i].match(/^\s*\d+\.\s/)) {
          items.push(lines[i].replace(/^\s*\d+\.\s/, ''))
          i += 1
        }
        const seg = new MdSegment()
        seg.type = 'list'
        seg.ordered = true
        seg.items = items
        segments.push(seg)
        continue
      }

      // Empty line
      if (line.trim().length === 0) {
        i += 1
        continue
      }

      // Paragraph (collect consecutive non-special lines)
      const paraLines: string[] = []
      while (i < lines.length) {
        const l = lines[i]
        if (l.trim().length === 0) break
        if (l.startsWith('```') || l.startsWith('#') || l.startsWith('>') ||
          l.match(/^\s*[-*+]\s/) || l.match(/^\s*\d+\.\s/)) break
        if (l.trim() === '---' || l.trim() === '***' || l.trim() === '___') break
        paraLines.push(l)
        i += 1
      }
      if (paraLines.length > 0) {
        const seg = new MdSegment()
        seg.type = 'paragraph'
        seg.text = paraLines.join(' ')
        segments.push(seg)
      }
    }

    return segments
  }

  /**
   * Parse inline formatting: **bold**, *italic*, `code`, [text](url)
   */
  static parseInline(text: string): InlineSpan[] {
    const spans: InlineSpan[] = []
    let i = 0
    let buffer = ''

    const flushBuffer = () => {
      if (buffer.length > 0) {
        const s = new InlineSpan()
        s.text = buffer
        spans.push(s)
        buffer = ''
      }
    }

    while (i < text.length) {
      // Bold: **text**
      if (i + 1 < text.length && text.charAt(i) === '*' && text.charAt(i + 1) === '*') {
        flushBuffer()
        const end = text.indexOf('**', i + 2)
        if (end >= 0) {
          const s = new InlineSpan()
          s.text = text.substring(i + 2, end)
          s.bold = true
          spans.push(s)
          i = end + 2
          continue
        }
      }

      // Italic: *text*
      if (text.charAt(i) === '*' && (i + 1 < text.length && text.charAt(i + 1) !== '*')) {
        flushBuffer()
        const end = text.indexOf('*', i + 1)
        if (end >= 0 && end > i + 1) {
          const s = new InlineSpan()
          s.text = text.substring(i + 1, end)
          s.italic = true
          spans.push(s)
          i = end + 1
          continue
        }
      }

      // Inline code: `text`
      if (text.charAt(i) === '`') {
        flushBuffer()
        const end = text.indexOf('`', i + 1)
        if (end >= 0) {
          const s = new InlineSpan()
          s.text = text.substring(i + 1, end)
          s.code = true
          spans.push(s)
          i = end + 1
          continue
        }
      }

      // Link: [text](url)
      if (text.charAt(i) === '[') {
        const closeBracket = text.indexOf(']', i + 1)
        if (closeBracket >= 0 && closeBracket + 1 < text.length && text.charAt(closeBracket + 1) === '(') {
          const closeParen = text.indexOf(')', closeBracket + 2)
          if (closeParen >= 0) {
            flushBuffer()
            const s = new InlineSpan()
            s.text = text.substring(i + 1, closeBracket)
            s.link = text.substring(closeBracket + 2, closeParen)
            spans.push(s)
            i = closeParen + 1
            continue
          }
        }
      }

      buffer += text.charAt(i)
      i += 1
    }
    flushBuffer()
    return spans
  }
}

/**
 * Markdown renderer component for ArkUI.
 * Renders parsed markdown segments with appropriate styling.
 */
@Component
export struct MarkdownRenderer {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop content: string = ''
  @Prop baseFontSize: number = 13

  build() {
    Column() {
      ForEach(MarkdownParser.parse(this.content), (seg: MdSegment, index: number) => {
        if (seg.type === 'heading') {
          this.RenderHeading(seg)
        } else if (seg.type === 'paragraph') {
          this.RenderParagraph(seg)
        } else if (seg.type === 'codeBlock') {
          this.RenderCodeBlock(seg)
        } else if (seg.type === 'list') {
          this.RenderList(seg)
        } else if (seg.type === 'blockquote') {
          this.RenderBlockquote(seg)
        } else if (seg.type === 'hr') {
          Divider()
            .strokeWidth(1)
            .color(Theme.BORDER)
            .margin({ top: Theme.sp.md, bottom: Theme.sp.md })
        }
      }, (seg: MdSegment, index: number) => `${index}-${seg.type}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RenderHeading(seg: MdSegment) {
    Text() {
      ForEach(MarkdownParser.parseInline(seg.text), (sp: InlineSpan) => {
        this.RenderSpan(sp, this.headingSize(seg.level))
      }, (sp: InlineSpan, idx: number) => `h-${idx}`)
    }
      .fontSize(this.headingSize(seg.level))
      .fontWeight(FontWeight.Bold)
      .fontColor(Theme.TEXT_PRIMARY)
      .margin({ top: Theme.sp.lg, bottom: Theme.sp.md })
      .width('100%')
  }

  @Builder
  RenderParagraph(seg: MdSegment) {
    Text() {
      ForEach(MarkdownParser.parseInline(seg.text), (sp: InlineSpan) => {
        this.RenderSpan(sp, this.baseFontSize)
      }, (sp: InlineSpan, idx: number) => `p-${idx}`)
    }
      .fontSize(this.baseFontSize)
      .fontColor(Theme.TEXT_PRIMARY)
      .lineHeight(this.baseFontSize + 7)
      .margin({ bottom: Theme.sp.md })
      .width('100%')
  }

  @Builder
  RenderSpan(sp: InlineSpan, fontSize: number) {
    if (sp.code) {
      Span(sp.text)
        .fontSize(fontSize - 1)
        .fontColor(Theme.WARNING)
        .fontFamily(Theme.FONT_MONO)
        .backgroundColor(Theme.CODE_BG)
        .borderRadius(2)
    } else if (sp.bold) {
      Span(sp.text)
        .fontSize(fontSize)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
    } else if (sp.italic) {
      Span(sp.text)
        .fontSize(fontSize)
        .fontStyle(FontStyle.Italic)
        .fontColor(Theme.TEXT_SECONDARY)
    } else if (sp.link.length > 0) {
      Span(sp.text)
        .fontSize(fontSize)
        .fontColor(Theme.ACCENT)
        .decoration({ type: TextDecorationType.Underline, color: Theme.ACCENT })
    } else {
      Span(sp.text)
        .fontSize(fontSize)
        .fontColor(Theme.TEXT_PRIMARY)
    }
  }

  @Builder
  RenderCodeBlock(seg: MdSegment) {
    Column() {
      // Language label + copy button
      if (seg.language.length > 0) {
        Row() {
          Text(seg.language)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Blank()
          Text('copy')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.ACCENT)
            .fontFamily(Theme.FONT_MONO)
        }
        .width('100%')
        .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.sm, bottom: Theme.sp.sm })
        .borderWidth({ bottom: 1 })
        .borderColor(Theme.CODE_BORDER)
      }

      // Code content
      Scroll() {
        Text(seg.text)
          .fontSize(Theme.fs.code)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontFamily(Theme.FONT_MONO)
          .lineHeight(Theme.fs.code + 6)
          .padding(Theme.sp.md)
          .width('100%')
      }
      .scrollBar(BarState.Auto)
      .constraintSize({ maxHeight: 300 })
    }
    .width('100%')
    .backgroundColor(Theme.CODE_BG)
    .borderRadius(Theme.rd.md)
    .borderWidth(1)
    .borderColor(Theme.CODE_BORDER)
    .margin({ top: Theme.sp.sm, bottom: Theme.sp.md })
  }

  @Builder
  RenderList(seg: MdSegment) {
    Column() {
      ForEach(seg.items, (item: string, idx: number) => {
        Row() {
          Text(seg.ordered ? `${idx + 1}.` : '-')
            .fontSize(this.baseFontSize)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .width(24)

          Text() {
            ForEach(MarkdownParser.parseInline(item), (sp: InlineSpan) => {
              this.RenderSpan(sp, this.baseFontSize)
            }, (sp: InlineSpan, sidx: number) => `li-${sidx}`)
          }
            .fontSize(this.baseFontSize)
            .fontColor(Theme.TEXT_PRIMARY)
            .lineHeight(this.baseFontSize + 7)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: Theme.sp.xs, bottom: Theme.sp.xs })
        .alignItems(VerticalAlign.Top)
      }, (item: string, idx: number) => `list-${idx}`)
    }
    .width('100%')
    .padding({ left: Theme.sp.md })
    .margin({ bottom: Theme.sp.md })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RenderBlockquote(seg: MdSegment) {
    Row() {
      Column()
        .width(3)
        .height('100%')
        .backgroundColor(Theme.ACCENT_DIM)
        .borderRadius(2)
        .margin({ right: Theme.sp.md })

      Text() {
        ForEach(MarkdownParser.parseInline(seg.text), (sp: InlineSpan) => {
          this.RenderSpan(sp, this.baseFontSize)
        }, (sp: InlineSpan, idx: number) => `bq-${idx}`)
      }
        .fontSize(this.baseFontSize)
        .fontColor(Theme.TEXT_SECONDARY)
        .fontStyle(FontStyle.Italic)
        .lineHeight(this.baseFontSize + 7)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: Theme.sp.md, top: Theme.sp.sm, bottom: Theme.sp.sm })
    .margin({ bottom: Theme.sp.md })
  }

  private headingSize(level: number): number {
    if (level === 1) return 22
    if (level === 2) return 18
    if (level === 3) return 16
    if (level === 4) return 14
    return 13
  }
}
