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

use std::borrow::Cow;
use std::sync::Arc;

use super::PgmonetaHandler;
use rmcp::ErrorData as McpError;
use rmcp::handler::server::router::tool::{AsyncTool, ToolBase};
use rmcp::model::JsonObject;
use rmcp::schemars;

#[derive(Debug, Default, serde::Deserialize, schemars::JsonSchema)]
pub struct HiRequest {
    pub name: String,
}

pub struct HiTool;

impl ToolBase for HiTool {
    type Parameter = HiRequest;
    type Output = String;
    type Error = McpError;

    fn name() -> Cow<'static, str> {
        "get_hi".into()
    }

    fn description() -> Option<Cow<'static, str>> {
        Some(
            "Get a Hi message with the provided name".into(),
        )
    }

    fn output_schema() -> Option<Arc<JsonObject>> {
        None
    }
}

impl AsyncTool<PgmonetaHandler> for HiTool {
    
    async fn invoke(_service: &PgmonetaHandler, request: HiRequest) -> Result<String, McpError> {
        println!("Received request: {}", request.name);
        let result = format!("Hi, {}!", request.name);
        let map_result = serde_json::json!({ "Outcome": result });
        PgmonetaHandler::generate_call_tool_result_string(&map_result.to_string())
    }
}