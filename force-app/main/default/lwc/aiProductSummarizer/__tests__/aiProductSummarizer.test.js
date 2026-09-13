import { createElement } from "lwc";
import AiProductSummarizer from "c/aiProductSummarizer";
import generateSummary from "@salesforce/apex/AIProductSummaryService.generateSummary";
import saveSummary from "@salesforce/apex/AIProductSummaryService.saveSummary";

jest.mock(
  "@salesforce/apex/AIProductSummaryService.generateSummary",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/AIProductSummaryService.saveSummary",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
};

function createComponent() {
  const element = createElement("c-ai-product-summarizer", {
    is: AiProductSummarizer
  });
  element.recordId = "01t000000000001AAA";
  document.body.appendChild(element);
  return element;
}

describe("c-ai-product-summarizer", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders default language", () => {
    const element = createComponent();
    const combo = element.shadowRoot.querySelector("lightning-combobox");
    expect(combo.value).toBe("English");
    expect(combo.options.map((option) => option.value)).toEqual([
      "English",
      "Spanish",
      "Portuguese",
      "Hindi"
    ]);
  });

  it("updates language and calls generate", async () => {
    generateSummary.mockResolvedValue({
      status: "Success",
      statusMessage: "Summary generated.",
      summary: "Generated summary",
      warnings: ["warning one"],
      decodedTerms: { LMS: "Learning Management System" }
    });

    const element = createComponent();
    const combo = element.shadowRoot.querySelector("lightning-combobox");
    combo.dispatchEvent(
      new CustomEvent("change", { detail: { value: "Spanish" } })
    );

    const generateButton = element.shadowRoot.querySelector(
      'lightning-button[data-id="generate"]'
    );
    generateButton.click();
    await flushPromises();

    expect(generateSummary).toHaveBeenCalledWith({
      productId: "01t000000000001AAA",
      language: "Spanish"
    });
    const summaryInput = element.shadowRoot.querySelector("lightning-textarea");
    expect(summaryInput.value).toBe("Generated summary");
  });

  it("calls save with edited summary", async () => {
    generateSummary.mockResolvedValue({
      status: "Success",
      statusMessage: "Summary generated.",
      summary: "Generated summary"
    });
    saveSummary.mockResolvedValue({
      status: "Success",
      statusMessage: "Summary saved."
    });

    const element = createComponent();
    const generateButton = element.shadowRoot.querySelector(
      'lightning-button[data-id="generate"]'
    );
    generateButton.click();
    await flushPromises();

    const textarea = element.shadowRoot.querySelector("lightning-textarea");
    textarea.dispatchEvent(
      new CustomEvent("change", { detail: { value: "Approved summary text" } })
    );
    await flushPromises();

    const saveButton = element.shadowRoot.querySelector(
      'lightning-button[data-id="save"]'
    );
    saveButton.click();
    await flushPromises();

    expect(saveSummary).toHaveBeenCalledWith({
      productId: "01t000000000001AAA",
      language: "English",
      approvedSummary: "Approved summary text"
    });
  });

  it("calls save with Hindi when selected", async () => {
    generateSummary.mockResolvedValue({
      status: "Success",
      statusMessage: "Summary generated.",
      summary: "Generated summary"
    });
    saveSummary.mockResolvedValue({
      status: "Success",
      statusMessage: "Summary saved."
    });

    const element = createComponent();
    const combo = element.shadowRoot.querySelector("lightning-combobox");
    combo.dispatchEvent(
      new CustomEvent("change", { detail: { value: "Hindi" } })
    );

    const generateButton = element.shadowRoot.querySelector(
      'lightning-button[data-id="generate"]'
    );
    generateButton.click();
    await flushPromises();

    const saveButton = element.shadowRoot.querySelector(
      'lightning-button[data-id="save"]'
    );
    saveButton.click();
    await flushPromises();

    expect(saveSummary).toHaveBeenCalledWith({
      productId: "01t000000000001AAA",
      language: "Hindi",
      approvedSummary: "Generated summary"
    });
  });

  it("clears generated content when language changes", async () => {
    generateSummary.mockResolvedValue({
      status: "Success",
      summary: "Generated summary"
    });

    const element = createComponent();
    const generateButton = element.shadowRoot.querySelector(
      'lightning-button[data-id="generate"]'
    );
    generateButton.click();
    await flushPromises();

    const combo = element.shadowRoot.querySelector("lightning-combobox");
    combo.dispatchEvent(
      new CustomEvent("change", { detail: { value: "Spanish" } })
    );
    await flushPromises();

    const summaryInput = element.shadowRoot.querySelector("lightning-textarea");
    expect(summaryInput.value).toBe("");
  });

  it("shows error message on generate failure", async () => {
    const consoleError = jest.spyOn(console, "error").mockImplementation();
    generateSummary.mockRejectedValue(new Error("Network failure"));
    const element = createComponent();

    const generateButton = element.shadowRoot.querySelector(
      'lightning-button[data-id="generate"]'
    );
    generateButton.click();
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "Failed to generate summary."
    );
    expect(consoleError).toHaveBeenCalled();
    consoleError.mockRestore();
  });
});
