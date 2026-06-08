import { storageService, AppSettings } from '../services/StorageService'
import { providerRegistry } from '../services/ProviderRegistry'
import { CNProvider, CNModel } from '../models/Provider'
import { Theme } from '../components/Theme'
import { ProviderIcon } from '../components/ProviderIcon'

/**
 * Settings Page — OpenCode Desktop-style tabbed settings dialog (M16)
 *
 * Layout: left sidebar with 5 navigation tabs, right scrollable content panel.
 * Tabs: General | Models | Providers | Servers (stub) | Keybinds
 */
@Component
export struct SettingsPage {
  onClose: () => void = () => {}

  // ══════════ State ══════════
  @State activeTab: string = 'general'
  @State settings: AppSettings = new AppSettings()
  @State statusMsg: string = ''
  @State showClearConfirm: boolean = false
  @State modelSearch: string = ''
  @State policyOverrides: Record<string, string> = {}
  @StorageProp('themeId') themeId: string = 'catppuccin'

  // ══════════ Lifecycle ══════════
  async aboutToAppear(): Promise<void> {
    this.settings = await storageService.loadSettings()
  }

  // ══════════ Root Build ══════════
  build() {
    Column() {
      // ── Header bar ──
      Row() {
        Text('SETTINGS')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
        Blank()
        Text('\u2715')
          .fontSize(Theme.fs.lg)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .padding({
            left: Theme.sp.lg,
            right: Theme.sp.lg,
            top: Theme.sp.sm,
            bottom: Theme.sp.sm
          })
          .onClick(() => {
            this.onClose()
          })
      }
      .width('100%')
      .padding({
        left: Theme.sp.xl,
        right: Theme.sp.xl,
        top: Theme.sp.lg,
        bottom: Theme.sp.md
      })

      // ── Body: sidebar + content ──
      Row() {
        // ── Left sidebar ──
        Column() {
          ForEach(
            ['general', 'models', 'providers', 'servers', 'keybinds'],
            (tab: string) => {
              Text(tab)
                .fontSize(Theme.fs.sm)
                .fontFamily(Theme.FONT_MONO)
                .fontWeight(this.activeTab === tab ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.activeTab === tab ? Theme.ACCENT : Theme.TEXT_MUTED)
                .backgroundColor(this.activeTab === tab ? Theme.ACTIVE_BG : 'transparent')
                .width('100%')
                .padding({
                  left: Theme.sp.xl,
                  right: Theme.sp.xl,
                  top: Theme.sp.lg,
                  bottom: Theme.sp.lg
                })
                .borderRadius(Theme.rd.md)
                .onClick(() => {
                  this.activeTab = tab
                })
            },
            (tab: string) => tab
          )
          Blank()
        }
        .width(140)
        .height('100%')
        .backgroundColor(Theme.PANEL)
        .padding({ top: Theme.sp.md, bottom: Theme.sp.md })
        .alignItems(HorizontalAlign.Start)

        // ── Right content panel ──
        Column() {
          Scroll() {
            Column() {
              if (this.activeTab === 'general') {
                this.GeneralTab()
              } else if (this.activeTab === 'models') {
                this.ModelsTab()
              } else if (this.activeTab === 'providers') {
                this.ProvidersTab()
              } else if (this.activeTab === 'servers') {
                this.ServersTab()
              } else if (this.activeTab === 'keybinds') {
                this.KeybindsTab()
              }
            }
            .padding(Theme.sp.xxl)
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        }
        .layoutWeight(1)
        .height('100%')
        .backgroundColor(Theme.BG)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }

  // ══════════════════════════════════════════════════════════════
  //  GENERAL TAB
  // ══════════════════════════════════════════════════════════════
  @Builder
  GeneralTab() {
    // ── About ──
    this.SectionHeader('ABOUT')
    Column() {
      this.InfoRow('app', 'OpenCode Harmony Native')
      this.InfoRow('version', 'v0.1.0')
      this.InfoRow('stage', 'phase 1 — tech preview')
      this.InfoRow('runtime', 'HarmonyOS ArkTS')
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .borderRadius(Theme.rd.lg)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: Theme.sp.xxl })

    // ── Display ──
    this.SectionHeader('DISPLAY')
    Column() {
      Row() {
        Text('font size')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_SECONDARY)
          .fontFamily(Theme.FONT_MONO)
          .layoutWeight(1)
        Text(`${this.settings.fontSize}`)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
        Slider({
          value: this.settings.fontSize,
          min: 10,
          max: 22,
          step: 1
        })
          .width(120)
          .margin({ left: Theme.sp.lg })
          .onChange((value: number) => {
            this.settings.fontSize = Math.round(value)
          })
      }
      .width('100%')
      .padding({ bottom: Theme.sp.lg })

      Row() {
        Text('dark mode')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_SECONDARY)
          .fontFamily(Theme.FONT_MONO)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.settings.darkMode })
          .selectedColor(Theme.ACCENT)
          .onChange((isOn: boolean) => {
            this.settings.darkMode = isOn
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .borderRadius(Theme.rd.lg)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: Theme.sp.xxl })
    .alignItems(HorizontalAlign.Start)

    // ── Theme ──
    this.SectionHeader('THEME')
    Column() {
      ForEach(Theme.themeNames(), (name: string) => {
        Row() {
          // Theme name
          Text(name)
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_PRIMARY)
            .fontFamily(Theme.FONT_MONO)
            .layoutWeight(1)
          // Active indicator
          if (this.themeId === name) {
            Text('active')
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.SUCCESS)
              .fontFamily(Theme.FONT_MONO)
              .backgroundColor(Theme.SUCCESS_DIM)
              .borderRadius(Theme.rd.sm)
              .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
          }
        }
        .width('100%')
        .padding({ left: Theme.sp.xl, right: Theme.sp.xl, top: Theme.sp.lg, bottom: Theme.sp.lg })
        .backgroundColor(this.themeId === name ? Theme.ACTIVE_BG : 'transparent')
        .borderRadius(Theme.rd.md)
        .onClick(() => {
          Theme.switchTheme(name)
        })
      }, (name: string) => name)
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .borderRadius(Theme.rd.lg)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: Theme.sp.xxl })
    .alignItems(HorizontalAlign.Start)

    // ── Defaults ──
    this.SectionHeader('DEFAULTS')
    Column() {
      this.SettingField('default agent', this.settings.defaultAgent, (v: string) => {
        this.settings.defaultAgent = v
      })
      this.SettingField('default model', this.settings.defaultModel, (v: string) => {
        this.settings.defaultModel = v
      })
      this.SettingField('small model', this.settings.defaultSmallModel, (v: string) => {
        this.settings.defaultSmallModel = v
      })
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .borderRadius(Theme.rd.lg)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: Theme.sp.xxl })
    .alignItems(HorizontalAlign.Start)

    // ── Approval Policy (toggleable ask / allow per row) ──
    this.SectionHeader('APPROVAL POLICY')
    Column() {
      this.PolicyRow('bash (execute)', this.getPolicy('bash'), () => {
        this.togglePolicy('bash')
      })
      this.PolicyRow('edit (file edit)', this.getPolicy('edit'), () => {
        this.togglePolicy('edit')
      })
      this.PolicyRow('write (file write)', this.getPolicy('write'), () => {
        this.togglePolicy('write')
      })
      this.PolicyRow('webfetch (fetch)', this.getPolicy('webfetch'), () => {
        this.togglePolicy('webfetch')
      })
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .borderRadius(Theme.rd.lg)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: Theme.sp.xxl })
    .alignItems(HorizontalAlign.Start)

    // ── Security ──
    this.SectionHeader('SECURITY')
    Column() {
      Row() {
        Text('server default host')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_SECONDARY)
          .fontFamily(Theme.FONT_MONO)
          .layoutWeight(1)
        Text('127.0.0.1')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
      }
      .width('100%')
      .padding({ bottom: Theme.sp.md })

      Row() {
        Text('API key masking')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_SECONDARY)
          .fontFamily(Theme.FONT_MONO)
          .layoutWeight(1)
        Text('enabled')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.SUCCESS)
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.SUCCESS_DIM)
          .borderRadius(Theme.rd.sm)
          .padding({
            left: Theme.sp.md,
            right: Theme.sp.md,
            top: Theme.sp.xs,
            bottom: Theme.sp.xs
          })
      }
      .width('100%')
      .padding({ bottom: Theme.sp.md })

      if (this.showClearConfirm) {
        Row() {
          Text('clear all local data?')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.DANGER)
            .fontFamily(Theme.FONT_MONO)
            .layoutWeight(1)
          Text('cancel')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_SECONDARY)
            .fontFamily(Theme.FONT_MONO)
            .padding({
              left: Theme.sp.lg,
              right: Theme.sp.lg,
              top: Theme.sp.md,
              bottom: Theme.sp.md
            })
            .borderRadius(Theme.rd.md)
            .backgroundColor(Theme.ACTIVE_BG)
            .onClick(() => {
              this.showClearConfirm = false
            })
          Text('confirm')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_INVERSE)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Bold)
            .padding({
              left: Theme.sp.lg,
              right: Theme.sp.lg,
              top: Theme.sp.md,
              bottom: Theme.sp.md
            })
            .borderRadius(Theme.rd.md)
            .backgroundColor(Theme.DANGER)
            .margin({ left: Theme.sp.md })
            .onClick(async () => {
              await storageService.clearAll()
              this.showClearConfirm = false
              this.statusMsg = 'local data cleared'
            })
        }
        .width('100%')
        .padding({ top: Theme.sp.md })
      } else {
        Text('clear local data')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.DANGER)
          .fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(Theme.sp.lg)
          .borderRadius(Theme.rd.lg)
          .backgroundColor(Theme.DANGER_DIM)
          .borderWidth(1)
          .borderColor(Theme.DANGER)
          .margin({ top: Theme.sp.md })
          .onClick(() => {
            this.showClearConfirm = true
          })
      }
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .borderRadius(Theme.rd.lg)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: Theme.sp.xxl })
    .alignItems(HorizontalAlign.Start)

    // ── Save button ──
    Text('save settings')
      .fontSize(Theme.fs.sm)
      .fontColor(Theme.TEXT_INVERSE)
      .fontFamily(Theme.FONT_MONO)
      .fontWeight(FontWeight.Bold)
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding(Theme.sp.lg)
      .borderRadius(Theme.rd.lg)
      .backgroundColor(Theme.ACCENT)
      .onClick(async () => {
        await storageService.saveSettings(this.settings)
        this.statusMsg = 'settings saved'
      })

    // ── Status message ──
    if (this.statusMsg.length > 0) {
      Text(this.statusMsg)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.SUCCESS)
        .fontFamily(Theme.FONT_MONO)
        .margin({ top: Theme.sp.lg })
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  MODELS TAB
  // ══════════════════════════════════════════════════════════════
  @Builder
  ModelsTab() {
    // ── Search input ──
    this.SectionHeader('SEARCH MODELS')
    TextInput({ text: this.modelSearch, placeholder: 'filter models...' })
      .width('100%')
      .height(36)
      .fontSize(Theme.fs.sm)
      .backgroundColor(Theme.INPUT_BG)
      .borderRadius(Theme.rd.lg)
      .borderWidth(1)
      .borderColor(Theme.BORDER)
      .fontColor(Theme.TEXT_PRIMARY)
      .margin({ bottom: Theme.sp.xxl })
      .onChange((v: string) => {
        this.modelSearch = v
      })

    // ── Model list grouped by provider ──
    this.SectionHeader('MODELS BY PROVIDER')

    ForEach(this.getFilteredProviders(), (p: CNProvider) => {
      Column() {
        // Provider group header
        Row() {
          Text(p.name)
            .fontSize(Theme.fs.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_SECONDARY)
            .fontFamily(Theme.FONT_MONO)
            .letterSpacing(0.5)
          Blank()
          Text(`${p.id}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
        }
        .width('100%')
        .padding({ bottom: Theme.sp.md })

        // Model rows within this provider group
        ForEach(this.getFilteredModels(p), (m: CNModel) => {
          Row() {
            // Green dot indicator for default model
            if (this.settings.defaultModel === `${p.id}/${m.id}`) {
              Circle()
                .width(8)
                .height(8)
                .fill(Theme.SUCCESS)
                .margin({ right: Theme.sp.md })
            }

            Text(m.name)
              .fontSize(Theme.fs.sm)
              .fontColor(Theme.TEXT_PRIMARY)
              .fontFamily(Theme.FONT_MONO)
              .layoutWeight(1)

            Text(m.id)
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .margin({ right: Theme.sp.lg })

            // Enabled toggle
            Toggle({ type: ToggleType.Switch, isOn: m.enabled })
              .selectedColor(Theme.ACCENT)
              .onChange((isOn: boolean) => {
                m.enabled = isOn
                providerRegistry.save()
              })

            // Set as default button
            Text('default')
              .fontSize(Theme.fs.xs)
              .fontColor(
                this.settings.defaultModel === `${p.id}/${m.id}`
                  ? Theme.SUCCESS
                  : Theme.TEXT_MUTED
              )
              .fontFamily(Theme.FONT_MONO)
              .padding({
                left: Theme.sp.md,
                right: Theme.sp.md,
                top: Theme.sp.xs,
                bottom: Theme.sp.xs
              })
              .borderRadius(Theme.rd.sm)
              .backgroundColor(
                this.settings.defaultModel === `${p.id}/${m.id}`
                  ? Theme.SUCCESS_DIM
                  : Theme.ACTIVE_BG
              )
              .margin({ left: Theme.sp.md })
              .onClick(() => {
                this.settings.defaultModel = `${p.id}/${m.id}`
              })
          }
          .width('100%')
          .padding({ top: Theme.sp.md, bottom: Theme.sp.md })
        }, (m: CNModel) => `${p.id}/${m.id}`)
      }
      .width('100%')
      .padding(Theme.sp.xl)
      .borderRadius(Theme.rd.lg)
      .backgroundColor(Theme.SIDEBAR)
      .borderWidth(1)
      .borderColor(Theme.BORDER)
      .margin({ bottom: Theme.sp.lg })
      .alignItems(HorizontalAlign.Start)
    }, (p: CNProvider) => p.id)

    if (this.getFilteredProviders().length === 0) {
      Text('no models match your search')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding(Theme.sp.xxl)
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  PROVIDERS TAB
  // ══════════════════════════════════════════════════════════════
  @Builder
  ProvidersTab() {
    this.SectionHeader('PROVIDERS')

    ForEach(providerRegistry.getAll(), (p: CNProvider) => {
      Row() {
        // Provider brand icon
        ProviderIcon({ providerId: p.id, size: 28 })
          .margin({ right: Theme.sp.lg })

        // Connection status indicator (green dot if API key is configured)
        Circle()
          .width(8)
          .height(8)
          .fill(p.authStatus === 'configured' ? Theme.SUCCESS : Theme.TEXT_MUTED)
          .margin({ right: Theme.sp.lg })

        Column() {
          Text(p.name)
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_PRIMARY)
            .fontFamily(Theme.FONT_MONO)
          Text(p.baseURL)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.xs })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // Manage button — navigates to full provider page
        Text('manage')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.ACCENT)
          .fontFamily(Theme.FONT_MONO)
          .padding({
            left: Theme.sp.lg,
            right: Theme.sp.lg,
            top: Theme.sp.md,
            bottom: Theme.sp.md
          })
          .borderRadius(Theme.rd.md)
          .backgroundColor(Theme.ACCENT_DIM)
      }
      .width('100%')
      .padding(Theme.sp.xl)
      .borderRadius(Theme.rd.lg)
      .backgroundColor(Theme.SIDEBAR)
      .borderWidth(1)
      .borderColor(Theme.BORDER)
      .margin({ bottom: Theme.sp.lg })
    }, (p: CNProvider) => p.id)
  }

  // ══════════════════════════════════════════════════════════════
  //  SERVERS TAB (Stub — M19)
  // ══════════════════════════════════════════════════════════════
  @Builder
  ServersTab() {
    this.SectionHeader('MCP SERVERS')

    Text('MCP server management — coming in M19')
      .fontSize(Theme.fs.sm)
      .fontColor(Theme.TEXT_MUTED)
      .fontFamily(Theme.FONT_MONO)
      .margin({ bottom: Theme.sp.xxl })

    // Placeholder list showing example servers in disabled state
    ForEach(
      ['filesystem-server', 'github-server', 'postgres-server'],
      (serverName: string) => {
        Row() {
          Circle()
            .width(8)
            .height(8)
            .fill(Theme.TEXT_MUTED)
            .margin({ right: Theme.sp.lg })

          Text(serverName)
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .layoutWeight(1)

          Text('disabled')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .backgroundColor(Theme.ACTIVE_BG)
            .borderRadius(Theme.rd.sm)
            .padding({
              left: Theme.sp.md,
              right: Theme.sp.md,
              top: Theme.sp.xs,
              bottom: Theme.sp.xs
            })
        }
        .width('100%')
        .padding(Theme.sp.xl)
        .borderRadius(Theme.rd.lg)
        .backgroundColor(Theme.SIDEBAR)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .margin({ bottom: Theme.sp.lg })
        .opacity(0.5)
      },
      (serverName: string) => serverName
    )
  }

  // ══════════════════════════════════════════════════════════════
  //  KEYBINDS TAB
  // ══════════════════════════════════════════════════════════════
  @Builder
  KeybindsTab() {
    this.SectionHeader('KEYBOARD SHORTCUTS')

    ForEach(this.getKeybindEntries(), (entry: string[]) => {
      Row() {
        Text(entry[0])
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_SECONDARY)
          .fontFamily(Theme.FONT_MONO)
          .layoutWeight(1)

        // Key combo badge
        Text(entry[1])
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(Theme.ACTIVE_BG)
          .borderRadius(Theme.rd.md)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .padding({
            left: Theme.sp.lg,
            right: Theme.sp.lg,
            top: Theme.sp.md,
            bottom: Theme.sp.md
          })
      }
      .width('100%')
      .padding({
        left: Theme.sp.xl,
        right: Theme.sp.xl,
        top: Theme.sp.lg,
        bottom: Theme.sp.lg
      })
      .borderRadius(Theme.rd.lg)
      .backgroundColor(Theme.SIDEBAR)
      .borderWidth(1)
      .borderColor(Theme.BORDER)
      .margin({ bottom: Theme.sp.md })
    }, (entry: string[]) => entry[0])

    // Note about editing
    Text('editing keybinds is not yet implemented')
      .fontSize(Theme.fs.xs)
      .fontColor(Theme.TEXT_MUTED)
      .fontFamily(Theme.FONT_MONO)
      .width('100%')
      .textAlign(TextAlign.Center)
      .margin({ top: Theme.sp.xl })
      .padding(Theme.sp.lg)
  }

  // ══════════════════════════════════════════════════════════════
  //  SHARED BUILDERS
  // ══════════════════════════════════════════════════════════════

  @Builder
  SectionHeader(title: string) {
    Text(title)
      .fontSize(Theme.fs.xs)
      .fontWeight(FontWeight.Bold)
      .fontColor(Theme.TEXT_MUTED)
      .fontFamily(Theme.FONT_MONO)
      .letterSpacing(1)
      .margin({ bottom: Theme.sp.lg })
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
        .width(100)
      Text(value)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontFamily(Theme.FONT_MONO)
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: Theme.sp.md })
  }

  @Builder
  SettingField(label: string, value: string, onChange: (v: string) => void) {
    Column() {
      Text(label)
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
        .margin({ bottom: Theme.sp.sm })
      TextInput({ text: value, placeholder: label })
        .width('100%')
        .height(36)
        .fontSize(Theme.fs.sm)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(Theme.rd.lg)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .fontColor(Theme.TEXT_PRIMARY)
        .onChange((v: string) => onChange(v))
    }
    .width('100%')
    .margin({ bottom: Theme.sp.lg })
  }

  @Builder
  PolicyRow(label: string, policy: string, onToggle: () => void) {
    Row() {
      Text(label)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
        .fontFamily(Theme.FONT_MONO)
        .layoutWeight(1)
      Text(policy === 'ask' ? 'ask' : 'allow')
        .fontSize(Theme.fs.xs)
        .fontColor(policy === 'ask' ? Theme.WARNING : Theme.SUCCESS)
        .fontFamily(Theme.FONT_MONO)
        .backgroundColor(policy === 'ask' ? Theme.WARNING_DIM : Theme.SUCCESS_DIM)
        .borderRadius(Theme.rd.sm)
        .padding({
          left: Theme.sp.md,
          right: Theme.sp.md,
          top: Theme.sp.xs,
          bottom: Theme.sp.xs
        })
        .onClick(() => {
          onToggle()
        })
    }
    .width('100%')
    .padding({ bottom: Theme.sp.md })
  }

  // ══════════════════════════════════════════════════════════════
  //  HELPER METHODS
  // ══════════════════════════════════════════════════════════════

  /**
   * Return the approval policy for a given tool category.
   * Checks policyOverrides @State first, then falls back to defaults.
   * Default policies: bash/edit/write = 'ask', webfetch = 'allow'.
   */
  private getPolicy(tool: string): string {
    if (this.policyOverrides[tool] !== undefined) {
      return this.policyOverrides[tool]
    }
    if (tool === 'webfetch') {
      return 'allow'
    }
    return 'ask'
  }

  /**
   * Toggle a tool's approval policy between 'ask' and 'allow'.
   * Creates a new Record reference so @State detects the change and re-renders.
   */
  private togglePolicy(tool: string): void {
    const current = this.getPolicy(tool)
    const next = current === 'ask' ? 'allow' : 'ask'
    const updated: Record<string, string> = {}
    const keys = Object.keys(this.policyOverrides)
    for (let i = 0; i < keys.length; i++) {
      updated[keys[i]] = this.policyOverrides[keys[i]]
    }
    updated[tool] = next
    this.policyOverrides = updated
  }

  /**
   * Get providers filtered by the current model search query.
   * Only providers with at least one matching model are returned.
   */
  private getFilteredProviders(): CNProvider[] {
    const providers = providerRegistry.getAll()
    if (this.modelSearch.length === 0) {
      return providers
    }
    const query = this.modelSearch.toLowerCase()
    const result: CNProvider[] = []
    for (let i = 0; i < providers.length; i++) {
      const p = providers[i]
      const nameMatch = p.name.toLowerCase().indexOf(query) >= 0
      const idMatch = p.id.toLowerCase().indexOf(query) >= 0
      if (nameMatch || idMatch) {
        result.push(p)
        continue
      }
      const hasMatchingModel = this.hasMatchingModel(p, query)
      if (hasMatchingModel) {
        result.push(p)
      }
    }
    return result
  }

  /**
   * Check whether a provider has any model matching the given query.
   */
  private hasMatchingModel(p: CNProvider, query: string): boolean {
    for (let i = 0; i < p.models.length; i++) {
      const m = p.models[i]
      if (m.name.toLowerCase().indexOf(query) >= 0 ||
          m.id.toLowerCase().indexOf(query) >= 0) {
        return true
      }
    }
    return false
  }

  /**
   * Get models within a provider that match the current search query.
   * If no search query, returns all models for the provider.
   */
  private getFilteredModels(p: CNProvider): CNModel[] {
    if (this.modelSearch.length === 0) {
      return p.models
    }
    const query = this.modelSearch.toLowerCase()
    const pNameMatch = p.name.toLowerCase().indexOf(query) >= 0
    const pIdMatch = p.id.toLowerCase().indexOf(query) >= 0
    if (pNameMatch || pIdMatch) {
      return p.models
    }
    const result: CNModel[] = []
    for (let i = 0; i < p.models.length; i++) {
      const m = p.models[i]
      if (m.name.toLowerCase().indexOf(query) >= 0 ||
          m.id.toLowerCase().indexOf(query) >= 0) {
        result.push(m)
      }
    }
    return result
  }

  /**
   * Return the static keybind entries as a 2D string array.
   * Each entry is [actionLabel, keyCombo].
   */
  private getKeybindEntries(): string[][] {
    return [
      ['Send message', 'Shift + Enter'],
      ['New session', 'Ctrl + N'],
      ['Switch tab', 'Ctrl + Tab'],
      ['Abort', 'Escape'],
      ['Toggle sidebar', 'Ctrl + B']
    ]
  }
}
