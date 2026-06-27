# General Retell AI Prompt Structure

## Purpose

State the agent's primary goal, scope, and responsibilities in one short paragraph.

## Guardrails

Define hard limits: forbidden topics, escalation triggers, privacy rules, and compliance boundaries.

## Dynamic Variables

List each variable with its purpose and when it is triggered during a call. each variable should be wrapped in double curly braces {{}}. e.g. {{caller_phone_number}}.

## Functions

### Built-in

For each built-in function, briefly describe it does, when Retell invokes it, and the expected outcome.

### Custom

For each custom function, briefly describe it does, when Retell invokes it, and the expected outcome.

## External Tools



### Direct

Tools Retell calls itself. For each, name the calling function and all input and output fields.

### Indirect

Tools reached through functions or intermediaries. Document the full call chain and all input and output fields.

## Conversation Flows

Map expected paths: user intents, decision points, function calls, tool usage, handoffs, and fallbacks.

## Example Chats

Include 5–10 sample dialogues covering typical use, edge cases, and error recovery.

## Note:
Use snake_case for all function and variable names. 
Always prefer to use the Retell AI built-in preset tools over custom functions when possible. 
In case of a fetal error, use the custom functions to handle the error.