import {NgModule, APP_INITIALIZER, Injector} from '@angular/core';
import {CommonModule} from '@angular/common';
import {OpenprojectCommonModule} from 'core-app/modules/common/openproject-common.module';
import {CsvImportAttachmentsComponent} from './csv-imports/attachments.component';
import {OpenprojectAttachmentsModule} from 'core-app/modules/attachments/openproject-attachments.module';
import {OpenProjectPluginContext} from 'core-app/modules/plugins/plugin-context';
import {multiInput} from 'reactivestates';
import {CsvImportResource} from './csv-imports/resource';
import {HalResource} from 'core-app/modules/hal/resources/hal-resource';

export function initializeCsvImportPlugin() {
  return () => {
    window.OpenProject.getPluginContext().then((pluginContext:OpenProjectPluginContext) => {
      let halResourceService = pluginContext.services.halResource;
      halResourceService.registerResource('CsvImport', {cls: CsvImportResource});

      let states = pluginContext.services.states;
      states.add('csvImports', multiInput<HalResource>());
    });
  }
}

@NgModule({
  imports: [
    CommonModule,

    OpenprojectCommonModule,
    OpenprojectAttachmentsModule
  ],
  providers: [
    { provide: APP_INITIALIZER, useFactory: initializeCsvImportPlugin, deps: [Injector], multi: true },
  ],
  declarations: [
    CsvImportAttachmentsComponent
  ],
  exports: [
  ],
  entryComponents: [
    CsvImportAttachmentsComponent
  ]

})
export class PluginModule {
}
