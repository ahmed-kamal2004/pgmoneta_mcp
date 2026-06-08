// Copyright (C) 2026 The pgmoneta community
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

use super::PgmonetaClient;
use crate::constant::Command;
use serde::Serialize;

#[derive(Serialize, Clone, Debug)]
struct AnnotateRequest {
    #[serde(rename = "Server")]
    server: String,
    #[serde(rename = "Backup")]
    backup: String,
    #[serde(rename = "Action")]
    action: String,
    #[serde(rename = "Key")]
    key: String,
    #[serde(rename = "Comment", skip_serializing_if = "Option::is_none")]
    comment: Option<String>,
}

impl PgmonetaClient {
    pub async fn request_annotate(
        username: &str,
        server: &str,
        backup: &str,
        action: &str,
        key: &str,
        comment: Option<&str>,
    ) -> anyhow::Result<String> {
        let request = AnnotateRequest {
            server: server.to_string(),
            backup: backup.to_string(),
            action: action.to_string(),
            key: key.to_string(),
            comment: comment.map(|value| value.to_string()),
        };
        Self::forward_request(username, Command::ANNOTATE, request).await
    }
}
