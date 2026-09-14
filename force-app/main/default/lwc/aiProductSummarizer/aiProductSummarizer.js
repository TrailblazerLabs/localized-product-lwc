import { LightningElement, api, track } from "lwc";
import generateSummary from "@salesforce/apex/AIProductSummaryService.generateSummary";
import saveSummary from "@salesforce/apex/AIProductSummaryService.saveSummary";

const LANGUAGE_OPTIONS = [
  { label: "English", value: "English" },
  { label: "Spanish", value: "Spanish" },
  { label: "Portuguese", value: "Portuguese" },
  { label: "Hindi", value: "Hindi" }
];

export default class AiProductSummarizer extends LightningElement {
  @api recordId;

  @track language = "English";
  @track summary = "";
  @track bestFitCustomer = "";
  @track positioningBullets = [];
  @track warnings = [];
  @track decodedTerms = [];
  @track statusMessage = "";
  @track statusVariant = "neutral";
  @track isGenerating = false;
  @track isSaving = false;
  generatedLanguage;

  get languageOptions() {
    return LANGUAGE_OPTIONS;
  }

  get canGenerate() {
    return !this.isGenerating && !this.isSaving && !!this.recordId;
  }

  get canSave() {
    return (
      !this.isGenerating &&
      !this.isSaving &&
      !!this.recordId &&
      !!this.summary &&
      this.generatedLanguage === this.language
    );
  }

  get generateDisabled() {
    return !this.canGenerate;
  }

  get saveDisabled() {
    return !this.canSave;
  }

  get hasWarnings() {
    return this.warnings.length > 0;
  }

  get hasDecodedTerms() {
    return this.decodedTerms.length > 0;
  }

  get hasPositioningBullets() {
    return this.positioningBullets.length > 0;
  }

  get positioningBulletsText() {
    return this.positioningBullets.join(" | ");
  }

  get decodedTermsText() {
    return this.decodedTerms
      .map((term) => `${term.abbreviation} - ${term.expansion}`)
      .join(" | ");
  }

  get warningsText() {
    return this.warnings.join(" | ");
  }

  get isBusy() {
    return this.isGenerating || this.isSaving;
  }

  handleLanguageChange(event) {
    const nextLanguage = event.detail.value;
    if (nextLanguage !== this.language) {
      this.language = nextLanguage;
      this.clearGeneratedOutput();
    }
  }

  handleSummaryChange(event) {
    this.summary = event.detail.value;
  }

  async handleGenerate() {
    if (!this.canGenerate) {
      return;
    }

    const requestLanguage = this.language;
    this.isGenerating = true;
    this.statusMessage = "";

    try {
      const result = await generateSummary({
        productId: this.recordId,
        language: requestLanguage
      });
      if (this.language !== requestLanguage) {
        return;
      }
      this.applyResult(result, requestLanguage);
    } catch (error) {
      if (this.language !== requestLanguage) {
        return;
      }
      this.setErrorState(error, "Failed to generate summary.");
    } finally {
      this.isGenerating = false;
    }
  }

  async handleSave() {
    if (!this.canSave) {
      return;
    }

    this.isSaving = true;
    this.statusMessage = "";

    try {
      const result = await saveSummary({
        productId: this.recordId,
        language: this.language,
        approvedSummary: this.summary
      });
      if (result?.status === "Success") {
        this.statusVariant = "success";
        this.statusMessage = result.statusMessage || "Summary saved.";
        this.generatedLanguage = this.language;
      } else {
        this.statusVariant = "error";
        this.statusMessage = result?.statusMessage || "Failed to save summary.";
      }
    } catch (error) {
      this.setErrorState(error, "Failed to save summary.");
    } finally {
      this.isSaving = false;
    }
  }

  applyResult(result, resultLanguage) {
    this.summary = result?.summary || "";
    this.bestFitCustomer = result?.bestFitCustomer || "";
    this.positioningBullets = result?.positioningBullets || [];
    this.warnings = result?.warnings || [];
    this.generatedLanguage = resultLanguage;

    const termMap = result?.decodedTerms || {};
    this.decodedTerms = Object.keys(termMap).map((key) => ({
      abbreviation: key,
      expansion: termMap[key]
    }));

    if (result?.status === "Success") {
      this.statusVariant = "success";
      this.statusMessage = result.statusMessage || "Summary generated.";
    } else {
      this.statusVariant = "error";
      this.statusMessage =
        result?.statusMessage || "Failed to generate summary.";
    }
  }

  setErrorState(error, fallbackMessage) {
    this.statusVariant = "error";
    this.statusMessage = fallbackMessage;
    // Surface full details only to logs, not users.
    console.error("AI Product Summarizer error", error);
  }

  clearGeneratedOutput() {
    this.summary = "";
    this.bestFitCustomer = "";
    this.positioningBullets = [];
    this.warnings = [];
    this.decodedTerms = [];
    this.generatedLanguage = null;
    this.statusVariant = "neutral";
    this.statusMessage = "";
  }
}
