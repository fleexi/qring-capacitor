# whesp-wirstband-capacitor

- Repository del plugin Wristband, spostato da `../../tyb-wirstband/capacitor-wristband` alla directory WHESP comune dei plugin. Nome npm corrente: `whesp-wirstband-capacitor`.
- Non aggiungere test o file di test per le attività OnActive. Conservare i test preesistenti; verificare con `npm run typecheck`, `npm run build` e build native del consumer.
- Applicazione consumer: `../../onactive-app`. Dopo modifiche eseguire da OnActive `npm run update-wristband-plugin` e la sincronizzazione del flavour interessato.
- SDK originali: `../../../tyb-wirstband` rispetto alla radice di questo plugin. I binari necessari a iOS/Android sono inclusi rispettivamente in `ios/Vendor` e `android/vendor`.
- Preservare le modifiche locali preesistenti e lo storico Git. Nessuna creazione di task Jira, branch, commit o push è implicita in una modifica del plugin.
- Le API native registrate restano `Wristband`, il prodotto Swift `WhespWirstbandCapacitor` e il namespace Android `it.tyb.wristband`.
