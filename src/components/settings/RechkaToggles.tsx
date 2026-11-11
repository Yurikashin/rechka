import React from "react";
import { useTranslation } from "react-i18next";
import { ToggleSwitch } from "../ui/ToggleSwitch";
import { useSettings } from "../../hooks/useSettings";

interface ToggleProps {
  descriptionMode?: "inline" | "tooltip";
  grouped?: boolean;
}

/** Rechka: "отправить" / "send it" at the end of a phrase submits it. */
export const VoiceSendToggle: React.FC<ToggleProps> = React.memo(
  ({ descriptionMode = "tooltip", grouped = false }) => {
    const { t } = useTranslation();
    const { getSetting, updateSetting, isUpdating } = useSettings();
    const enabled = getSetting("voice_send_enabled") ?? true;
    return (
      <ToggleSwitch
        checked={enabled}
        onChange={(value) => updateSetting("voice_send_enabled", value)}
        isUpdating={isUpdating("voice_send_enabled")}
        label={t("settings.rechka.voiceSend.label")}
        description={t("settings.rechka.voiceSend.description")}
        descriptionMode={descriptionMode}
        grouped={grouped}
      />
    );
  },
);

/** Rechka: format text for the app it goes into. */
export const AppStylesToggle: React.FC<ToggleProps> = React.memo(
  ({ descriptionMode = "tooltip", grouped = false }) => {
    const { t } = useTranslation();
    const { getSetting, updateSetting, isUpdating } = useSettings();
    const enabled = getSetting("app_styles_enabled") ?? true;
    return (
      <ToggleSwitch
        checked={enabled}
        onChange={(value) => updateSetting("app_styles_enabled", value)}
        isUpdating={isUpdating("app_styles_enabled")}
        label={t("settings.rechka.appStyles.label")}
        description={t("settings.rechka.appStyles.description")}
        descriptionMode={descriptionMode}
        grouped={grouped}
      />
    );
  },
);
