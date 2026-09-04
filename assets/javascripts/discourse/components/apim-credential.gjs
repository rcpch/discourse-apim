import { on } from "@ember/modifier";
import UsageChart from "./usage-chart";

<template>
  <div class="apim-credential">
    <div class="credential-header">
      <div class="credential-title">
        {{@credential.displayName}}
      </div>
    </div>
    <div class="credential-action">
      {{#if @credential.apiKey}}
        <code>{{@credential.apiKey}}</code>
      {{else if @credential.enabled}}
        <button {{on "click" @showApiKey}} class="btn">Show API key</button>
      {{else}}
        <button {{on "click" @createApiKey}} class="btn">Sign up</button>
      {{/if}}
    </div>
    {{#if @credential.usage.length}}
      <div class="credential-usage">
        <div class="credential-usage-this-month credential-stat">
          <div class="credential-stat-number">
            {{@credential.callsThisMonth}}
          </div>
          <div class="credential-stat-description">
            calls this month
          </div>
        </div>
        <div class="credential-usage-last-year">
          <UsageChart @data={{@credential.usage}} />
        </div>
      </div>
    {{/if}}
  </div>
</template>
