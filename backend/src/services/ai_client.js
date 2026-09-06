"use strict";
// simple AI adapter example
// reads IA_PROVIDER env var and dispatches to different clients
const fs = require('fs')

class AIClient {
  constructor() {
    this.provider = process.env.IA_PROVIDER || 'none'
  }

  async generate(prompt) {
    if (this.provider === 'openai') {
      // placeholder: call OpenAI using OPENAI_API_KEY
      return `OpenAI response for: ${prompt}`
    }
    if (this.provider === 'local') {
      // call local LLM endpoint
      return `Local LLM response for: ${prompt}`
    }
    throw new Error('No AI provider configured')
  }
}

module.exports = new AIClient()
