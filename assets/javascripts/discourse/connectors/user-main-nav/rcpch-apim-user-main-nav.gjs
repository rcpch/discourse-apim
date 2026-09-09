import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";

<template>
  <LinkTo @route="user.apim">
    {{icon "server"}}
    API keys
  </LinkTo>
</template>
