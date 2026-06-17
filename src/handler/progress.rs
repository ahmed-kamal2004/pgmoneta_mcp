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

use super::PgmonetaHandler;
use crate::client::PgmonetaClient;
use rmcp::ErrorData as McpError;
use rmcp::handler::server::router::tool::{AsyncTool, ToolBase};
use rmcp::schemars;
use std::borrow::Cow;

#[derive(Debug, Default, serde::Deserialize, schemars::JsonSchema)]
pub struct ProgressRequest {
    pub username: String,
    pub server: String,
    pub command: String,
}

/// Tool for checking the progress of an operation.
pub struct ProgressTool;

impl ToolBase for ProgressTool {
    type Parameter = ProgressRequest;
    type Output = String;
    type Error = McpError;

    fn name() -> Cow<'static, str> {
        "progress".into()
    }

    fn description() -> Option<std::borrow::Cow<'static, str>> {
        Some(
            "Get the progress of an operation. \
            Requires a server name and a command which the operation is associated with (backup, restore, or delete). \
            The username has to be one of the pgmoneta admins to be able to access pgmoneta."
                .into(),
        )
    }

    fn output_schema() -> Option<std::sync::Arc<rmcp::model::JsonObject>> {
        None
    }
}

impl AsyncTool<PgmonetaHandler> for ProgressTool {
    async fn invoke(
        _service: &PgmonetaHandler,
        request: ProgressRequest,
    ) -> Result<String, McpError> {
        if request.command != "backup" {
            Err(McpError::invalid_params(
                "Progress supports only command of 'backup'".to_string(),
                None,
            ))
        } else {
            let result = PgmonetaClient::request_progress(
                &request.username,
                &request.server,
                &request.command,
            )
            .await
            .map_err(|e| {
                McpError::internal_error(format!("Failed to get progress: {:?}", e), None)
            })?;
            PgmonetaHandler::generate_call_tool_result_string(&result)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::handler::PgmonetaHandler;
    use rmcp::handler::server::router::tool::ToolBase;
    use serde_json::{Map, Value};

    #[test]
    fn test_progress_tool_metadata() {
        let name = ProgressTool::name();
        assert_eq!(name, "progress");
        let description = ProgressTool::description().unwrap();
        assert!(description.contains("Get the progress of an operation"));
    }

    #[test]
    fn test_handler_has_progress_tool() {
        let tools = PgmonetaHandler::tool_router().list_all();
        let tool_names: Vec<String> = tools
            .iter()
            .map(|tool| tool.name.as_ref().to_string())
            .collect();
        assert!(
            tool_names.contains(&"progress".to_string()),
            "Progress tool should be registered in the handler, found tools: {:?}",
            tool_names
        );
    }

    #[test]
    fn test_generate_call_tool_result_string_progress() {
        let response = r#"{"Outcome": {"Status": true, "Command": 25}}"#;
        let result = PgmonetaHandler::generate_call_tool_result_string(response);
        assert!(result.is_ok());
        let output = result.unwrap();
        let parsed: Map<String, Value> = serde_json::from_str(&output).unwrap();
        let outcome = parsed["Outcome"].as_object().unwrap();
        assert_eq!(outcome["Command"], "progress");
    }

    #[test]
    fn test_progress_response_with_error_setup_failed() {
        let response = r#"{"Outcome": {"Status": false, "Command": 25, "Error": {"Code": 3000, "Message": "Setup failed"}}}"#;
        let result = PgmonetaHandler::generate_call_tool_result_string(response);
        assert!(result.is_ok());
        let output = result.unwrap();
        let parsed: Map<String, Value> = serde_json::from_str(&output).unwrap();
        let outcome = parsed["Outcome"].as_object().unwrap();
        assert_eq!(outcome["Command"], "progress");
        assert_eq!(outcome["Status"], false);
        let error = outcome["Error"].as_object().unwrap();
        assert_eq!(error["Code"], 3000);
        assert_eq!(error["Message"], "Setup failed");
    }
}
