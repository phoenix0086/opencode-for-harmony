import { Theme } from './Theme'
import { SessionInfo } from '../models/Event'
import { formatServerTitle } from '../utils/DateTimeUtil'

/**
 * Data model for a single session tab in the tab bar.
 */
export class SessionTab {
  id: string = ''
  title: string = ''
  isActive: boolean = false
}

/**
 * Horizontal tab bar showing open sessions.
 * Supports tab selection, closing, and creating new tabs.
 */
@Component
export struct SessionTabs {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop tabs: SessionTab[] = []
  @Prop activeTabId: string = ''
  onSelectTab: (id: string) => void = () => {}
  onCloseTab: (id: string) => void = () => {}
  onNewTab: () => void = () => {}

  @State hoveredTabId: string = ''

  build() {
    Scroll() {
      Row() {
        ForEach(this.tabs, (tab: SessionTab) => {
          Column() {
            Row() {
              Text(tab.title.length > 0 ? tab.title : 'New Session')
                .fontSize(Theme.fs.sm)
                .fontColor(tab.id === this.activeTabId
                  ? Theme.TEXT_PRIMARY
                  : Theme.TEXT_MUTED)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .constraintSize({ maxWidth: 120 })
                .layoutWeight(1)

              Text('\u00d7')
                .fontSize(Theme.fs.md)
                .fontColor(Theme.TEXT_MUTED)
                .textAlign(TextAlign.Center)
                .width(16)
                .height(16)
                .borderRadius(Theme.rd.sm)
                .backgroundColor(tab.id === this.hoveredTabId
                  ? Theme.HOVER
                  : Color.Transparent)
                .visibility(tab.id === this.activeTabId ||
                  tab.id === this.hoveredTabId
                  ? Visibility.Visible
                  : Visibility.None)
                .onClick(() => {
                  this.onCloseTab(tab.id)
                })
            }
            .width('100%')
            .height(34)
            .padding({
              left: Theme.sp.lg,
              right: Theme.sp.md
            })
            .alignItems(VerticalAlign.Center)

            // Active indicator bar
            Row()
              .width('100%')
              .height(2)
              .backgroundColor(tab.id === this.activeTabId
                ? Theme.ACCENT
                : Color.Transparent)
          }
          .height(36)
          .onClick(() => {
            this.onSelectTab(tab.id)
          })
          .onHover((isHovered: boolean) => {
            this.hoveredTabId = isHovered ? tab.id : ''
          })
        }, (tab: SessionTab): string => tab.id)

        // Add-new-tab button
        Text('+')
          .fontSize(Theme.fs.xl)
          .fontColor(Theme.TEXT_MUTED)
          .textAlign(TextAlign.Center)
          .width(36)
          .height(36)
          .onClick(() => {
            this.onNewTab()
          })
      }
      .height(36)
      .alignItems(VerticalAlign.Bottom)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(36)
    .backgroundColor(Theme.PANEL)
    .borderWidth({ bottom: 1 })
    .borderColor(Theme.BORDER)
  }
}
