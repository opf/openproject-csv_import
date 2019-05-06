import {HalResource} from 'core-app/modules/hal/resources/hal-resource';
import {Attachable} from 'core-app/modules/hal/resources/mixins/attachable-mixin';
import {AttachmentCollectionResource} from 'core-app/modules/hal/resources/attachment-collection-resource';

interface CsvImportResourceLinks {
  addAttachment(attachment:HalResource):Promise<any>;
}

export class CsvImportBaseResource extends HalResource {
  public $links:CsvImportResourceLinks;

  private attachmentsBackend = true;
  readonly id:string;
  public attachments:AttachmentCollectionResource;

  /**
   * Invalidate a set of linked resources of this work package.
   * And inform the cache service about the work package update.
   *
   * Return a promise that returns the linked resources as properties.
   * Return a rejected promise, if the resource is not a property of the work package.
   */
  public updateLinkedResources(...resourceNames:string[]):Promise<any> {
    const resources:{ [id:string]:Promise<HalResource> } = {};

    resourceNames.forEach(name => {
      const linked = this[name];
      resources[name] = linked ? linked.$update() : Promise.reject(undefined);
    });

    const promise = Promise.all(_.values(resources));
    promise.then(() => {
      this.states.forResource(this).putValue(this, 'Attachment uploaded');
    });

    return promise;
  }

  /**
   * Get updated attachments and activities from the server and inform the cache service
   * about the update.
   *
   * Return a promise that returns the attachments. Reject, if the work package has
   * no attachments.
   */
  public updateAttachments():Promise<HalResource> {
    return this
      .updateLinkedResources('attachments')
      .then((resources:any) => resources.attachments);
  }
}

export const CsvImportResource = Attachable(CsvImportBaseResource);
