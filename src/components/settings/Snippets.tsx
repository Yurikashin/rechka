import React, { useState } from "react";
import { useTranslation } from "react-i18next";
import type { Snippet } from "@/bindings";
import { notify } from "@/stores/noticeStore";
import { useSettings } from "../../hooks/useSettings";
import { isComposingKeyEvent } from "../../lib/utils/keyboard";
import { Input } from "../ui/Input";
import { Button } from "../ui/Button";
import { SettingContainer } from "../ui/SettingContainer";

interface SnippetsProps {
  descriptionMode?: "inline" | "tooltip";
  grouped?: boolean;
}

/** Same folding as the backend's `normalize_phrase`, for duplicate checks. */
const normalizeTrigger = (text: string) =>
  text
    .toLowerCase()
    .replace(/ё/g, "е")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();

/** Rechka: whole-phrase voice shortcuts that expand into saved text. */
export const Snippets: React.FC<SnippetsProps> = React.memo(
  ({ descriptionMode = "tooltip", grouped = false }) => {
    const { t } = useTranslation();
    const { getSetting, updateSetting, isUpdating } = useSettings();
    const [trigger, setTrigger] = useState("");
    const [text, setText] = useState("");
    const snippets: Snippet[] = getSetting("snippets") || [];
    const busy = isUpdating("snippets");
    const canAdd =
      normalizeTrigger(trigger).length > 0 &&
      trigger.trim().length <= 60 &&
      text.trim().length > 0 &&
      text.length <= 2000;

    const handleAdd = () => {
      if (!canAdd) return;
      const key = normalizeTrigger(trigger);
      if (snippets.some((s) => normalizeTrigger(s.trigger) === key)) {
        notify({
          title: t("settings.rechka.snippets.duplicate", {
            trigger: trigger.trim(),
          }),
        });
        return;
      }
      updateSetting("snippets", [
        ...snippets,
        { trigger: trigger.trim(), text },
      ]);
      setTrigger("");
      setText("");
    };

    const handleRemove = (index: number) => {
      updateSetting(
        "snippets",
        snippets.filter((_, i) => i !== index),
      );
    };

    const handleKeyDown = (e: React.KeyboardEvent) => {
      if (isComposingKeyEvent(e.nativeEvent)) return;
      if (e.key === "Enter") {
        e.preventDefault();
        handleAdd();
      }
    };

    return (
      <>
        <SettingContainer
          title={t("settings.rechka.snippets.title")}
          description={t("settings.rechka.snippets.description")}
          descriptionMode={descriptionMode}
          grouped={grouped}
        >
          <div className="flex flex-wrap items-center gap-2">
            <Input
              type="text"
              className="max-w-40"
              value={trigger}
              onChange={(e) => setTrigger(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={t("settings.rechka.snippets.triggerPlaceholder")}
              aria-label={t("settings.rechka.snippets.triggerPlaceholder")}
              variant="compact"
              disabled={busy}
            />
            <Input
              type="text"
              className="max-w-56"
              value={text}
              onChange={(e) => setText(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={t("settings.rechka.snippets.textPlaceholder")}
              aria-label={t("settings.rechka.snippets.textPlaceholder")}
              variant="compact"
              disabled={busy}
            />
            <Button
              onClick={handleAdd}
              disabled={!canAdd || busy}
              variant="primary"
              size="md"
            >
              {t("settings.rechka.snippets.add")}
            </Button>
          </div>
        </SettingContainer>
        {snippets.length > 0 && (
          <ul
            className={`px-4 p-2 ${grouped ? "" : "rounded-lg border border-line"} flex flex-col gap-1`}
          >
            {snippets.map((snippet, index) => (
              <li
                key={`${snippet.trigger}-${index}`}
                className="flex items-center gap-2 text-sm"
              >
                <span className="font-semibold">«{snippet.trigger}»</span>
                <span className="text-ink-3">→</span>
                <span className="truncate flex-1" title={snippet.text}>
                  {snippet.text}
                </span>
                <Button
                  onClick={() => handleRemove(index)}
                  disabled={busy}
                  variant="secondary"
                  size="sm"
                  aria-label={t("settings.rechka.snippets.remove", {
                    trigger: snippet.trigger,
                  })}
                >
                  {t("settings.rechka.snippets.removeShort")}
                </Button>
              </li>
            ))}
          </ul>
        )}
      </>
    );
  },
);
