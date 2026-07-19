use std::{cmp::Ordering, fs, path::PathBuf, process::Command};

use serde::{Deserialize, Serialize};

const LATEST_RELEASE_URL: &str = "https://api.github.com/repos/douxy1994/ChatMem/releases/latest";
const CURRENT_VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GithubUpdateCheck {
    pub should_update: bool,
    pub version: String,
    pub notes: Option<String>,
    pub published_at: Option<String>,
    pub asset_name: Option<String>,
}

#[derive(Debug, Deserialize)]
struct GithubRelease {
    tag_name: String,
    body: Option<String>,
    published_at: Option<String>,
    assets: Vec<GithubAsset>,
}

#[derive(Debug, Clone, Deserialize)]
struct GithubAsset {
    name: String,
    browser_download_url: String,
}

#[tauri::command]
pub async fn check_github_release_update() -> Result<GithubUpdateCheck, String> {
    let release = fetch_latest_release().await?;
    let version = normalize_version(&release.tag_name);
    let should_update = compare_versions(&version, CURRENT_VERSION) == Ordering::Greater;
    let asset_name = find_windows_installer_asset(&release).map(|asset| asset.name.clone());

    Ok(GithubUpdateCheck {
        should_update,
        version,
        notes: release.body,
        published_at: release.published_at,
        asset_name,
    })
}

#[tauri::command]
pub async fn install_github_release_update() -> Result<GithubUpdateCheck, String> {
    // The direct NSIS installer path only works on Windows. Other platforms
    // fall back to Tauri's signed updater in the frontend (updater.ts).
    if !cfg!(target_os = "windows") {
        return Err("github release installer is only available on windows".to_string());
    }

    let release = fetch_latest_release().await?;
    let version = normalize_version(&release.tag_name);
    if compare_versions(&version, CURRENT_VERSION) != Ordering::Greater {
        let asset_name = find_windows_installer_asset(&release).map(|asset| asset.name.clone());
        return Ok(GithubUpdateCheck {
            should_update: false,
            version,
            notes: release.body,
            published_at: release.published_at,
            asset_name,
        });
    }

    let asset = find_windows_installer_asset(&release)
        .ok_or_else(|| format!("Release {} does not include a Windows installer.", release.tag_name))?
        .clone();
    let installer_path = download_installer(&release.tag_name, &asset).await?;
    launch_installer(&installer_path)?;

    Ok(GithubUpdateCheck {
        should_update: true,
        version,
        notes: release.body,
        published_at: release.published_at,
        asset_name: Some(asset.name),
    })
}

async fn fetch_latest_release() -> Result<GithubRelease, String> {
    let client = reqwest::Client::builder()
        .user_agent(format!("ChatMem/{}", CURRENT_VERSION))
        .build()
        .map_err(|error| error.to_string())?;

    let response = client
        .get(LATEST_RELEASE_URL)
        .send()
        .await
        .map_err(|error| format!("Unable to reach GitHub releases: {error}"))?;

    if !response.status().is_success() {
        return Err(format!(
            "GitHub release check failed with HTTP {}",
            response.status()
        ));
    }

    response
        .json::<GithubRelease>()
        .await
        .map_err(|error| format!("Invalid GitHub release response: {error}"))
}

async fn download_installer(tag_name: &str, asset: &GithubAsset) -> Result<PathBuf, String> {
    let client = reqwest::Client::builder()
        .user_agent(format!("ChatMem/{}", CURRENT_VERSION))
        .build()
        .map_err(|error| error.to_string())?;
    let response = client
        .get(&asset.browser_download_url)
        .send()
        .await
        .map_err(|error| format!("Unable to download update: {error}"))?;

    if !response.status().is_success() {
        return Err(format!(
            "Update download failed with HTTP {}",
            response.status()
        ));
    }

    let bytes = response
        .bytes()
        .await
        .map_err(|error| format!("Unable to read update download: {error}"))?;
    let safe_tag = sanitize_file_component(tag_name);
    let safe_name = sanitize_file_component(&asset.name);
    let path = std::env::temp_dir()
        .join("ChatMem")
        .join("updates")
        .join(safe_tag)
        .join(safe_name);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    fs::write(&path, bytes).map_err(|error| error.to_string())?;
    Ok(path)
}

fn launch_installer(path: &PathBuf) -> Result<(), String> {
    Command::new(path)
        .arg("/S")
        .spawn()
        .map_err(|error| format!("Unable to launch update installer: {error}"))?;
    std::process::exit(0);
}

fn find_windows_installer_asset(release: &GithubRelease) -> Option<&GithubAsset> {
    release
        .assets
        .iter()
        .find(|asset| {
            let name = asset.name.to_ascii_lowercase();
            name.ends_with("_x64-setup.exe")
                || name.ends_with("-setup.exe")
                || (name.ends_with(".exe") && name.contains("windows"))
                || (name.ends_with(".exe") && name.contains("win"))
        })
        .or_else(|| {
            release.assets.iter().find(|asset| {
                let name = asset.name.to_ascii_lowercase();
                name.ends_with(".exe") && name.contains("chatmem")
            })
        })
}

fn normalize_version(value: &str) -> String {
    value.trim().trim_start_matches('v').trim_start_matches('V').to_string()
}

fn compare_versions(left: &str, right: &str) -> Ordering {
    let left_parts = version_parts(left);
    let right_parts = version_parts(right);
    let max_len = left_parts.len().max(right_parts.len()).max(3);

    for index in 0..max_len {
        let left_value = left_parts.get(index).copied().unwrap_or(0);
        let right_value = right_parts.get(index).copied().unwrap_or(0);
        match left_value.cmp(&right_value) {
            Ordering::Equal => {}
            ordering => return ordering,
        }
    }

    Ordering::Equal
}

fn version_parts(version: &str) -> Vec<u64> {
    version
        .split(|character: char| !character.is_ascii_digit())
        .filter(|part| !part.is_empty())
        .filter_map(|part| part.parse::<u64>().ok())
        .collect()
}

fn sanitize_file_component(value: &str) -> String {
    value
        .chars()
        .map(|character| match character {
            'a'..='z' | 'A'..='Z' | '0'..='9' | '.' | '-' | '_' => character,
            _ => '_',
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::{compare_versions, normalize_version};
    use std::cmp::Ordering;

    #[test]
    fn compares_semver_like_versions() {
        assert_eq!(compare_versions("1.3.1", "1.3.0"), Ordering::Greater);
        assert_eq!(compare_versions("1.3.0", "1.3.0"), Ordering::Equal);
        assert_eq!(compare_versions("1.2.9", "1.3.0"), Ordering::Less);
    }

    #[test]
    fn normalizes_release_tags() {
        assert_eq!(normalize_version("v1.3.0"), "1.3.0");
        assert_eq!(normalize_version("V1.3.1"), "1.3.1");
    }
}
