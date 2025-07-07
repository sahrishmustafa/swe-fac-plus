from app.model import (
    azure,
    bedrock,
    claude,
    common,
    gemini,
    gpt,
    gptlitellm,
    groq,
    ollama,
    huggingface,
)


def register_all_models() -> None:
    """
    Register all models. This is called in main.
    """
    common.register_model(gpt.Gpt4o_20241120())
    common.register_model(gpt.Gpt4o_20240806())
    common.register_model(gpt.testgpt())
    common.register_model(gpt.Gpt4o_20240513())
    common.register_model(gpt.Gpt4o_mini_20240718())
    common.register_model(gpt.Gpt4_Turbo20240409())
    common.register_model(gpt.Gpt4_0125Preview())
    common.register_model(gpt.Gpt4_1106Preview())
    common.register_model(gpt.Gpt35_Turbo0125())
    common.register_model(gpt.Gpt35_Turbo1106())
    common.register_model(gpt.Gpt35_Turbo16k_0613())
    common.register_model(gpt.Gpt35_Turbo0613())
    common.register_model(gpt.Gpt4_0613())
    common.register_model(gpt.Gpt_o1mini())
    common.register_model(gpt.Qwen25_72B())
    common.register_model(gpt.DeepSeekV25())
    common.register_model(gpt.DeepSeekV3())
    common.register_model(gpt.DeepSeek())
    common.register_model(gpt.Gpt4_1())
    common.register_model(gpt.Gpt4_1_mini())
    common.register_model(gpt.Gemini_2_5_flash_preview())
    
    common.register_model(gpt.Gpt4_1_nano())
    common.register_model(gpt.Claude3_5Sonnet())
    common.register_model(gpt.Claude3_7Sonnet())
    common.register_model(claude.Claude3Opus())
    common.register_model(claude.Claude3Sonnet())
    common.register_model(claude.Claude3Haiku())
    # common.register_model(claude.Claude3_5Sonnet())

    common.register_model(bedrock.AnthropicClaude3Opus())
    common.register_model(bedrock.AnthropicClaude3Sonnet())
    common.register_model(bedrock.AnthropicClaude3Haiku())

    common.register_model(ollama.Llama3_8B())
    common.register_model(ollama.Llama3_70B())

    common.register_model(groq.Llama3_8B())
    common.register_model(groq.Llama3_70B())
    common.register_model(groq.Mixtral_8x7B())
    common.register_model(groq.Gemma_7B())

    common.register_model(gptlitellm.Gpt4o_20240513LiteLLM())
    common.register_model(gptlitellm.Gpt4_Turbo20240409LiteLLM())
    common.register_model(gptlitellm.Gpt4_0125PreviewLiteLLM())
    common.register_model(gptlitellm.Gpt4_1106PreviewLiteLLM())
    common.register_model(gptlitellm.Gpt35_Turbo0125LiteLLM())
    common.register_model(gptlitellm.Gpt35_Turbo1106LiteLLM())
    common.register_model(gptlitellm.Gpt35_Turbo16k_0613LiteLLM())
    common.register_model(gptlitellm.Gpt35_Turbo0613LiteLLM())
    common.register_model(gptlitellm.Gpt4_0613LiteLLM())


    common.register_model(azure.AzureGpt4())
    common.register_model(azure.AzureGpt4o())
    common.register_model(azure.AzureGpt35_Turbo())
    common.register_model(azure.AzureGpt35_Turbo16k())
    common.register_model(azure.AzureGpt_o1mini())

    common.register_model(gemini.GeminiPro())
    common.register_model(gemini.Gemini15Pro())

    common.register_model(huggingface.Llama3_8B_HF())
    common.register_model(huggingface.Gemma2B_HF())
    common.register_model(huggingface.Mistral7BInstruct_HF())
    common.register_model(huggingface.Zephyr7B_HF())

    # register default model as selected
    common.SELECTED_MODEL = gpt.Gpt35_Turbo0125()
