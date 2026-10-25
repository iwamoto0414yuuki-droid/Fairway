    async fn get_client_info(&self) -> Result<AnisetteClientInfo, Report> {
        let info = self.client_info.get_or_try_init(|| async {
            let info: AnisetteClientInfo = self.client
                .get(format!("{}/v3/client_info", self.url))
                .send().await.context("AUTH_METADATA: could not request server client information")?
                .error_for_status().context("AUTH_METADATA: server rejected client information request")?
                .json().await.context("AUTH_METADATA: invalid client information response")?;
            for value in [&info.client_info, &info.user_agent] {
                if value.trim().is_empty() || value.len() > 2048 || value.contains('\r') || value.contains('\n') {
                    bail!("AUTH_METADATA: invalid client information headers");
                }
                HeaderValue::from_str(value).context("AUTH_METADATA: unusable client information header")?;
            }
            Ok::<AnisetteClientInfo, Report>(info)
        }).await?;
        Ok(info.clone())
    }

    async fn provision(&mut self, gs: Arc<GrandSlam>, force_reset: bool) -> Result<(), Report> {
        self.get_client_info().await?;
        self.get_state(gs, force_reset).await?;
        Ok(())
    }
