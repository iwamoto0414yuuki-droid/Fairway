        let data = self.get_data_or_provision(&gs, 3).await?;
        let data = Arc::new(data);
        self.data = Some(data.clone());
        Ok(data)
    }

    async fn get_data_or_provision(&self, gs: &Arc<GrandSlam>, remaining: usize) -> Result<AnisetteData, Report> {
        if remaining == 0 { bail!("Anisette preparation retry limit reached; no Apple login was retried"); }
        let provider = self.provider.read().await;
        match provider.get_anisette_data().await? {
            AnisetteDataResponse::Data(data) => Ok(data),
            status @ (AnisetteDataResponse::NeedsProvisioning | AnisetteDataResponse::IncorrectlyProvisioned) => {
                drop(provider);
                let mut provider = self.provider.write().await;
                provider.provision(gs.clone(), matches!(status, AnisetteDataResponse::IncorrectlyProvisioned)).await?;
                drop(provider);
                Box::pin(self.get_data_or_provision(gs, remaining - 1)).await
            }
        }
    }
