import React, { useState } from "react";
import { useTranslation } from "react-i18next";
import type { Replacement } from "@/bindings";
import { notify } from "@/stores/noticeStore";
import { useSettings } from "../../hooks/useSettings";
import { isComposingKeyEvent } from "../../lib/utils/keyboard";
import { Input } from "../ui/Input";
import { Button } from "../ui/Button";
import { SettingContainer } from "../ui/SettingContainer";

interface ReplacementsProps {
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

/** Rechka: the user's whole-word replacements (e.g. a name always spelled one way). */
export const Replacements: React.FC<ReplacementsProps> = React.memo(
  ({ descriptionMode = "tooltip", grouped = false }) => {
    const { t } = useTranslation();
    const { getSetting, updateSetting, isUpdating } = useSettings();
    const [trigger, setTrigger] = useState("");
    const [text, setText] = useState("");
    const replacements: Replacement[] = getSetting("replacements") || [];
    const busy = isUpdating("replacements");
    const canAdd =
      normalizeTrigger(trigger).length > 0 &&
      trigger.trim().length <= 60 &&
      text.trim().length > 0 &&
      text.length <= 200;

    const handleAdd = () => {
      if (!canAdd) return;
      const key = normalizeTrigger(trigger);
      if (replacements.some((r) => normalizeTrigger(r.from) === key)) {
        notify({
          title: t("settings.rechka.replacements.duplicate", {
            trigger: trigger.trim(),
          }),
        });
        return;
      }
      updateSetting("replacements", [
        ...replacements,
        { from: trigger.trim(), to: text.trim() },
      ]);
      setTrigger("");
      setText("");
    };

    const handleRemove = (index: number) => {
      updateSetting(
        "replacements",
        replacements.filter((_, i) => i !== index),
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
          title={t("settings.rechka.replacements.title")}
          description={t("settings.rechka.replacements.description")}
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
              placeholder={t("settings.rechka.replacements.triggerPlaceholder")}
              aria-label={t("settings.rechka.replacements.triggerPlaceholder")}
              variant="compact"
              disabled={busy}
            />
            <Input
              type="text"
              className="max-w-56"
              value={text}
              onChange={(e) => setText(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={t("settings.rechka.replacements.textPlaceholder")}
              aria-label={t("settings.rechka.replacements.textPlaceholder")}
              variant="compact"
              disabled={busy}
            />
            <Button
              onClick={handleAdd}
              disabled={!canAdd || busy}
              variant="primary"
              size="md"
            >
              {t("settings.rechka.replacements.add")}
            </Button>
          </div>
        </SettingContainer>
        {replacements.length > 0 && (
          <ul
            className={`px-4 p-2 ${grouped ? "" : "rounded-lg border border-line"} flex flex-col gap-1`}
          >
            {replacements.map((item, index) => (
              <li
                key={`${item.from}-${index}`}
                className="flex items-center gap-2 text-sm"
              >
                <span className="font-semibold">«{item.from}»</span>
                <span className="text-ink-3">→</span>
                <span className="truncate flex-1" title={item.to}>
                  {item.to}
                </span>
                <Button
                  onClick={() => handleRemove(index)}
                  disabled={busy}
                  variant="secondary"
                  size="sm"
                  aria-label={t("settings.rechka.replacements.remove", {
                    trigger: item.from,
                  })}
                >
                  {t("settings.rechka.replacements.removeShort")}
                </Button>
              </li>
            ))}
          </ul>
        )}
      </>
    );
  },
);
