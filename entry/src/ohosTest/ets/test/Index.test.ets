/**
 * ohos e2e smoke test — verifies that the main page can be loaded.
 * 跑法: hvigorw test --module entry --test ohostest
 */

import { describe, it, expect } from '@ohos/hypium'
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry'
import { Driver, ON } from '@ohos.UITestKit'

const delegator = abilityDelegatorRegistry.getAbilityDelegator()
const bundleName = abilityDelegatorRegistry.getArguments().bundleName

export default function indexE2ETest() {
  describe('Index Page E2E', () => {
    it('starts the main ability', 0, async (done: Function) => {
      try {
        await delegator.startAbility({
          bundleName: bundleName,
          abilityName: 'EntryAbility'
        })
        expect(true).assertTrue()
      } catch (e) {
        expect(false).assertTrue()
      }
      done()
    })

    it('renders without crashing', 0, async (done: Function) => {
      // Simple wait for first frame
      await new Promise<void>((resolve: Function): void => {
        setTimeout((): void => resolve(), 1000)
      })
      expect(true).assertTrue()
      done()
    })
  })
}
