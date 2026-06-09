/** Explicit classes to avoid ArkTS untyped object literal errors. */
export class EmptyRequest {}
export class TextPromptPart { type: string = 'text'; text: string = ''; }
export class PromptAsyncRequest { agent: string = 'build'; parts: TextPromptPart[] = []; }
export class ConfigModelPatch { model: string = ''; }
export class ConfigSmallModelPatch { small_model: string = ''; }
export class ExecutionPollResult {
  ok: boolean = false; timedOut: boolean = false; hasAssistant: boolean = false; hasTool: boolean = false;
  hasError: boolean = false; hasPermission: boolean = false; message: string = ''; errorText: string = ''; messageCount: number = 0;
}
