//! Rechka additions on top of the Handy pipeline: snippets, the spoken
//! "send" command and per-app writing styles.
//!
//! Everything here is pure text logic except [`frontmost_bundle_id`], so the
//! behavior is covered by unit tests on every platform.

use crate::settings::{Replacement, Snippet};
use once_cell::sync::Lazy;
use regex::Regex;

/// Lower-cases, folds `ё` into `е`, drops punctuation and collapses spaces, so
/// a spoken phrase compares equal however the recognizer punctuated it.
pub fn normalize_phrase(text: &str) -> String {
    let folded: String = text
        .chars()
        .flat_map(char::to_lowercase)
        .map(|c| if c == 'ё' { 'е' } else { c })
        .map(|c| if c.is_alphanumeric() { c } else { ' ' })
        .collect();
    folded.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// The snippet whose trigger is the WHOLE dictated phrase. A trigger that is
/// only part of a sentence never fires, which keeps false expansions out.
pub fn match_snippet<'a>(text: &str, snippets: &'a [Snippet]) -> Option<&'a Snippet> {
    let spoken = normalize_phrase(text);
    if spoken.is_empty() {
        return None;
    }
    snippets
        .iter()
        .find(|s| !s.text.is_empty() && normalize_phrase(&s.trigger) == spoken)
}

/// Russian case endings a brand name picks up in speech ("в Гугле", "Гугла").
const NOUN_ENDINGS: &str = "(?:а|у|ом|е|ы|ов|ам|ами|ах|ой|ю|я|ем)?";

/// Brand and product names the recognizer writes in Cyrillic, with the Latin
/// spelling to restore. Each pattern is the Cyrillic stem; `+` marks that it
/// declines (takes [`NOUN_ENDINGS`]). Order matters: longer names first.
/// Ambiguous everyday words (кодекс, курсор, питон, хром, мак) are left out.
const LATIN_TERMS: &[(&str, &str)] = &[
    (r"(?:гугл|google)\s?хром+", "Google Chrome"),
    (r"(?:гугл|google)\s?док(?:с|и|ах|ов)", "Google Docs"),
    (r"(?:гугл|google)\s?мит+", "Google Meet"),
    (r"(?:гугл|google)\s?(?:диск|драйв)+", "Google Drive"),
    (r"(?:джи|г)\s?ме[йи]л+", "Gmail"),
    (r"(?:и|е)[-\s]?ме[йи]л+", "email"),
    (r"(?:эпп?|апп?|app)\s?стор+", "App Store"),
    (r"(?:гит|гет)\s?(?:хаб|хап)+", "GitHub"),
    (r"гит\s?лаб+", "GitLab"),
    (r"сафари", "Safari"),
    (r"(?:эпп?л|эпол)+", "Apple"),
    (r"м[еэ]йл+", "Mail"),
    (r"гу(?:гл|гол)+", "Google"),
    (r"ют(?:у|ю)б+", "YouTube"),
    (r"телеграмм?+", "Telegram"),
    (r"(?:ва|во)(?:тс|ц)апп?+", "WhatsApp"),
    (r"зум+", "Zoom"),
    (r"сл[аэ]к+", "Slack"),
    (r"ноуш[е]?н+", "Notion"),
    (r"фигм(?:а|ы|е|у|ой)", "Figma"),
    (r"айфон+", "iPhone"),
    (r"айпад+", "iPad"),
    (r"макбук+", "MacBook"),
    (r"айклауд+", "iCloud"),
    (r"мак\s?ос", "macOS"),
    (r"виндо(?:в|у)с", "Windows"),
    (r"майкрософт+", "Microsoft"),
    (r"[эе]ксел(?:ь|е|я|ю|ем)", "Excel"),
    (r"ворд+", "Word"),
    (r"па(?:уэ|ве)р\s?поинт+", "PowerPoint"),
    (r"(?:чат|chat)[-\s]?(?:гпт|gpt|джи\s?пи\s?ти)", "ChatGPT"),
    (r"оупен\s?эй\s?ай|опен\s?эй\s?ай|опенаи", "OpenAI"),
    (r"клод+", "Claude"),
    (r"антропик+", "Anthropic"),
    (r"докер+", "Docker"),
    (r"джава\s?скрипт+", "JavaScript"),
    (r"тайп\s?скрипт+", "TypeScript"),
    (r"пайтон+", "Python"),
    (r"линукс+", "Linux"),
    (r"инстаграм+", "Instagram"),
    (r"фейсбук+", "Facebook"),
    (r"тик\s?ток+", "TikTok"),
    (r"спотифай", "Spotify"),
    (r"дискорд+", "Discord"),
    (r"джир(?:а|ы|е|у|ой)", "Jira"),
    (r"трелло", "Trello"),
    (r"дропбокс+", "Dropbox"),
    (r"вай[-\s]?фай", "Wi-Fi"),
    (r"блюту(?:с|з)", "Bluetooth"),
];

static LATIN_TERM_PATTERNS: Lazy<Vec<(Regex, &'static str)>> = Lazy::new(|| {
    LATIN_TERMS
        .iter()
        .map(|(pattern, latin)| {
            let body = match pattern.strip_suffix('+') {
                Some(stem) => format!("(?:{stem}){NOUN_ENDINGS}"),
                None => format!("(?:{pattern})"),
            };
            let regex = Regex::new(&format!(r"(?i)\b{body}\b")).expect("valid brand pattern");
            (regex, *latin)
        })
        .collect()
});

/// Writes known brand and product names in Latin script: "в Гугле" -> "в Google".
pub fn apply_latin_terms(text: &str) -> String {
    let mut out = text.to_string();
    for (regex, latin) in LATIN_TERM_PATTERNS.iter() {
        if regex.is_match(&out) {
            out = regex.replace_all(&out, *latin).into_owned();
        }
    }
    out
}

/// Place names the recognizer writes in lower case or declines where the
/// name is used in its fixed form ("филиал Тушину" -> "филиал Тушино").
/// Each entry: pattern -> fixed spelling. Forms that are both correct and a
/// common surname ("Тушина") are left alone.
const PLACE_NAMES: &[(&str, &str)] = &[
    (r"путилков(?:о|а|у|ом|е)", "Путилково"),
    (r"тушин(?:о|у|ом)", "Тушино"),
    (r"химки", "Химки"),
    (r"химках", "Химках"),
    (r"химок", "Химок"),
    (r"химкам", "Химкам"),
    (r"химками", "Химками"),
];

static PLACE_NAME_PATTERNS: Lazy<Vec<(Regex, &'static str)>> = Lazy::new(|| {
    PLACE_NAMES
        .iter()
        .map(|(pattern, fixed)| {
            let regex =
                Regex::new(&format!(r"(?i)\b(?:{pattern})\b")).expect("valid place pattern");
            (regex, *fixed)
        })
        .collect()
});

/// Fixes spelling and capitalization of known place names.
pub fn apply_place_names(text: &str) -> String {
    let mut out = text.to_string();
    for (regex, fixed) in PLACE_NAME_PATTERNS.iter() {
        if regex.is_match(&out) {
            out = regex.replace_all(&out, *fixed).into_owned();
        }
    }
    out
}

/// The user's own whole-word replacements, case-insensitive, applied in order.
pub fn apply_replacements(text: &str, replacements: &[Replacement]) -> String {
    let mut out = text.to_string();
    for r in replacements {
        let from = r.from.trim();
        if from.is_empty() {
            continue;
        }
        let words: Vec<String> = from.split_whitespace().map(regex::escape).collect();
        let pattern = format!(r"(?i)\b{}\b", words.join(r"\s+"));
        if let Ok(regex) = Regex::new(&pattern) {
            out = regex.replace_all(&out, regex::NoExpand(&r.to)).into_owned();
        }
    }
    out
}

/// Spoken endings that mean "submit after pasting".
const SEND_ENDINGS: &[&[&str]] = &[
    &["send", "it"],
    &["отправить"],
    &["отправь"],
    &["отправляй"],
];

/// Removes a trailing spoken send command. Returns the text to paste (possibly
/// empty when the whole phrase was the command) and whether to submit.
pub fn strip_send_command(text: &str) -> (String, bool) {
    let words: Vec<&str> = text.split_whitespace().collect();
    for ending in SEND_ENDINGS {
        if words.len() < ending.len() {
            continue;
        }
        let tail = &words[words.len() - ending.len()..];
        let matches = tail
            .iter()
            .zip(ending.iter())
            .all(|(spoken, expected)| normalize_phrase(spoken) == *expected);
        if matches {
            let kept = words[..words.len() - ending.len()].join(" ");
            let kept = kept
                .trim_end_matches(|c: char| {
                    c == ',' || c == ';' || c == ':' || c == '-' || c == '—' || c.is_whitespace()
                })
                .to_string();
            return (kept, true);
        }
    }
    (text.to_string(), false)
}

/// Where the text is going, decided from the frontmost app.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AppStyle {
    /// Messengers: short, conversational, no final period.
    Chat,
    /// Mail clients: full sentences.
    Mail,
    /// Editors and terminals: identifiers as spoken, no final period.
    Code,
}

impl AppStyle {
    /// The built-in post-processing prompt for this style.
    pub fn prompt_id(self) -> &'static str {
        match self {
            AppStyle::Chat => RECHKA_STYLE_CHAT_PROMPT_ID,
            AppStyle::Mail => RECHKA_STYLE_MAIL_PROMPT_ID,
            AppStyle::Code => RECHKA_STYLE_CODE_PROMPT_ID,
        }
    }
}

pub const RECHKA_STYLE_CHAT_PROMPT_ID: &str = "rechka_style_chat";
pub const RECHKA_STYLE_MAIL_PROMPT_ID: &str = "rechka_style_mail";
pub const RECHKA_STYLE_CODE_PROMPT_ID: &str = "rechka_style_code";

const CHAT_APPS: &[&str] = &[
    "ru.keepcoder.Telegram",
    "org.telegram.desktop",
    "com.tdesktop.Telegram",
    "com.tinyspeck.slackmacgap",
    "net.whatsapp.WhatsApp",
    "desktop.WhatsApp",
    "com.apple.MobileSMS",
    "com.hnc.Discord",
    "com.microsoft.teams2",
    "com.microsoft.teams",
    "ru.vk.messenger",
    "com.viber.osx",
];

const MAIL_APPS: &[&str] = &[
    "com.apple.mail",
    "com.microsoft.Outlook",
    "com.readdle.smartemail-Mac",
    "com.readdle.SparkDesktop",
    "com.mimestream.Mimestream",
];

const CODE_APPS: &[&str] = &[
    "com.todesktop.230313mzl4w4u92", // Cursor
    "com.microsoft.VSCode",
    "com.microsoft.VSCodeInsiders",
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "dev.warp.Warp-Stable",
    "dev.zed.Zed",
    "com.apple.dt.Xcode",
    "com.openai.codex",
    "com.exafunction.windsurf",
];

/// The style for an app's bundle identifier; `None` keeps the user's defaults.
pub fn style_for_bundle_id(bundle_id: &str) -> Option<AppStyle> {
    if CHAT_APPS.contains(&bundle_id) {
        Some(AppStyle::Chat)
    } else if MAIL_APPS.contains(&bundle_id) {
        Some(AppStyle::Mail)
    } else if CODE_APPS.contains(&bundle_id) || bundle_id.starts_with("com.jetbrains.") {
        Some(AppStyle::Code)
    } else {
        None
    }
}

/// Local, model-free formatting for a style, applied after any LLM pass.
pub fn apply_local_style(text: &str, style: Option<AppStyle>) -> String {
    match style {
        Some(AppStyle::Chat) | Some(AppStyle::Code) => {
            // A single line ending in one period loses it; "..." and
            // multi-line text stay as they are.
            if !text.contains('\n') && text.ends_with('.') && !text.ends_with("..") {
                text[..text.len() - 1].to_string()
            } else {
                text.to_string()
            }
        }
        _ => text.to_string(),
    }
}

/// Bundle identifier of the frontmost application (macOS only).
#[cfg(target_os = "macos")]
pub fn frontmost_bundle_id() -> Option<String> {
    use objc2_app_kit::NSWorkspace;
    let workspace = NSWorkspace::sharedWorkspace();
    let app = workspace.frontmostApplication()?;
    app.bundleIdentifier().map(|id| id.to_string())
}

#[cfg(not(target_os = "macos"))]
pub fn frontmost_bundle_id() -> Option<String> {
    None
}

/// The style for whatever app is in front right now.
pub fn current_app_style() -> Option<AppStyle> {
    frontmost_bundle_id().and_then(|id| style_for_bundle_id(&id))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn snip(trigger: &str, text: &str) -> Snippet {
        Snippet {
            trigger: trigger.to_string(),
            text: text.to_string(),
        }
    }

    #[test]
    fn normalize_ignores_case_punctuation_and_yo() {
        assert_eq!(normalize_phrase("  Моя ПОДПИСЬ!  "), "моя подпись");
        assert_eq!(normalize_phrase("Ещё, раз."), "еще раз");
    }

    #[test]
    fn snippet_fires_only_on_the_whole_phrase() {
        let snippets = vec![snip("мой адрес", "Москва, ул. Примерная, 1")];
        assert_eq!(
            match_snippet("Мой адрес.", &snippets).map(|s| s.text.as_str()),
            Some("Москва, ул. Примерная, 1")
        );
        assert!(match_snippet("пришли мой адрес", &snippets).is_none());
        assert!(match_snippet("", &snippets).is_none());
    }

    #[test]
    fn empty_snippet_text_never_fires() {
        let snippets = vec![snip("подпись", "")];
        assert!(match_snippet("подпись", &snippets).is_none());
    }

    #[test]
    fn send_command_is_stripped_from_the_end() {
        assert_eq!(
            strip_send_command("Буду через пять минут, отправить."),
            ("Буду через пять минут".to_string(), true)
        );
        assert_eq!(
            strip_send_command("See you tomorrow, send it"),
            ("See you tomorrow".to_string(), true)
        );
        assert_eq!(strip_send_command("Отправь"), (String::new(), true));
    }

    #[test]
    fn send_word_inside_the_phrase_is_kept() {
        assert_eq!(
            strip_send_command("Надо отправить письмо завтра"),
            ("Надо отправить письмо завтра".to_string(), false)
        );
        assert_eq!(
            strip_send_command("I will send it later"),
            ("I will send it later".to_string(), false)
        );
    }

    #[test]
    fn styles_follow_bundle_ids() {
        assert_eq!(
            style_for_bundle_id("ru.keepcoder.Telegram"),
            Some(AppStyle::Chat)
        );
        assert_eq!(style_for_bundle_id("com.apple.mail"), Some(AppStyle::Mail));
        assert_eq!(
            style_for_bundle_id("com.jetbrains.pycharm"),
            Some(AppStyle::Code)
        );
        assert_eq!(style_for_bundle_id("com.apple.Safari"), None);
    }

    #[test]
    fn chat_style_drops_a_single_final_period() {
        assert_eq!(
            apply_local_style("Привет, как дела.", Some(AppStyle::Chat)),
            "Привет, как дела"
        );
        assert_eq!(apply_local_style("Ну...", Some(AppStyle::Chat)), "Ну...");
        assert_eq!(
            apply_local_style("Строка.\nЕщё.", Some(AppStyle::Chat)),
            "Строка.\nЕщё."
        );
        assert_eq!(
            apply_local_style("Добрый день.", Some(AppStyle::Mail)),
            "Добрый день."
        );
        assert_eq!(apply_local_style("Добрый день.", None), "Добрый день.");
    }

    #[test]
    fn brand_names_are_written_in_latin() {
        assert_eq!(
            apply_latin_terms("Открой Сафари, зайди в Гетхап и проверь почту в Эпл Мэйл."),
            "Открой Safari, зайди в GitHub и проверь почту в Apple Mail."
        );
        assert_eq!(apply_latin_terms("Найди в Гугле"), "Найди в Google");
        assert_eq!(
            apply_place_names("филиал Путилкова, филиал Тушину, филиал химки"),
            "филиал Путилково, филиал Тушино, филиал Химки"
        );
        assert_eq!(
            apply_place_names("Путилково тушино химки, в химках"),
            "Путилково Тушино Химки, в Химках"
        );
        assert_eq!(apply_place_names("Анна Тушина"), "Анна Тушина");
        assert_eq!(
            apply_latin_terms("файл на Google Драйв, спроси в чат GPT"),
            "файл на Google Drive, спроси в ChatGPT"
        );
        assert_eq!(
            apply_latin_terms("Гугл драйве и Чат GPT"),
            "Google Drive и ChatGPT"
        );
        assert_eq!(
            apply_latin_terms("гугл докс и гугл мит"),
            "Google Docs и Google Meet"
        );
        assert_eq!(apply_latin_terms("напиши в телеграме"), "напиши в Telegram");
        assert_eq!(apply_latin_terms("пришли на имейл"), "пришли на email");
        assert_eq!(apply_latin_terms("таблица в экселе"), "таблица в Excel");
    }

    #[test]
    fn ordinary_words_are_not_touched() {
        // A verb from a brand, everyday words that only look similar.
        assert_eq!(apply_latin_terms("надо погуглить"), "надо погуглить");
        assert_eq!(
            apply_latin_terms("Гражданский кодекс и курсор"),
            "Гражданский кодекс и курсор"
        );
        assert_eq!(apply_latin_terms("хромированный мак"), "хромированный мак");
        assert_eq!(apply_latin_terms("слаква"), "слаква");
    }

    #[test]
    fn user_replacements_match_whole_words() {
        let r = vec![
            Replacement {
                from: "краски детства".into(),
                to: "«Краски детства»".into(),
            },
            Replacement {
                from: "ри".into(),
                to: "RI".into(),
            },
        ];
        assert_eq!(
            apply_replacements("Садик Краски Детства, при этом ри", &r),
            "Садик «Краски детства», при этом RI"
        );
    }
}
