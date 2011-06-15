/**
 Copyright 2011 Red Hat, Inc.

 This software is licensed to you under the GNU General Public
 License as published by the Free Software Foundation; either version
 2 of the License (GPLv2) or (at your option) any later version.
 There is NO WARRANTY for this software, express or implied,
 including the implied warranties of MERCHANTABILITY,
 NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
 have received a copy of GPLv2 along with this software; if not, see
 http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
*/

/*
 * A small javascript file needed to load things whenever a provider is opened for editing
 */

$(document).ready(function() {

    $('.ajaxfileupload').each(function() {
        $(this).editable($(this).attr('url'), {
            type        :  'ajaxupload',
            method      :  'PUT',
            name        :  $(this).attr('name'),
            cancel      :  i18n.cancel,
            submit      :  i18n.upload,
            indicator   :  i18n.uploading,
            tooltip     :  i18n.clickToEdit,
            placeholder :  i18n.clickToEdit,
            submitdata  :  {authenticity_token: AUTH_TOKEN},
            onerror     :  function(settings, original, xhr) {
            original.reset();
                $("#notification").replaceWith(xhr.responseText);
            }
        });
    });

    $('.edit_password').each(function() {
        $(this).editable($(this).attr('url'), {
            type        :  'password',
            width       :  270,
            method      :  'PUT',
            name        :  $(this).attr('name'),
            cancel      :  i18n.cancel,
            submit      :  i18n.save,
            indicator   :  i18n.saving,
            tooltip     :  i18n.clickToEdit,
            placeholder :  i18n.clickToEdit,
            submitdata  :  {authenticity_token: AUTH_TOKEN},
            onerror     :  function(settings, original, xhr) {
            original.reset();
            $("#notification").replaceWith(xhr.responseText);
            }
        });
    });

    $('.edit_textfield').each(function() {
        $(this).editable($(this).attr('url'), {
            type        :  'text',
            width       :  270,                  
            method      :  'PUT',
            name        :  $(this).attr('name'),
            cancel      :  i18n.cancel,
            submit      :  i18n.save,
            indicator   :  i18n.saving,
            tooltip     :  i18n.clickToEdit,
            placeholder :  i18n.clickToEdit,
            submitdata  :  {authenticity_token: AUTH_TOKEN},
            onerror     :  function(settings, original, xhr) {
            original.reset();
            $("#notification").replaceWith(xhr.responseText);
            }
        });
    });

    $('.edit_textarea').each(function() {
        $(this).editable($(this).attr('url'), {
            type        :  'textarea',
            method      :  'PUT',
            name        :  $(this).attr('name'),
            cancel      :  i18n.cancel,
            submit      :  i18n.save,
            indicator   :  i18n.saving,
            tooltip     :  i18n.clickToEdit,
            placeholder :  i18n.clickToEdit,
            submitdata  :  {authenticity_token: AUTH_TOKEN},
            rows        :  8,
            cols        :  36,
            onerror     :  function(settings, original, xhr) {
            original.reset();
            $("#notification").replaceWith(xhr.responseText);
            }
        });
    });

    $('.edit_providername').each(function() {
        $(this).editable($(this).attr('url'), {
            type        :  'text',
            width       :  270,
            method      :  'PUT',
            name        :  $(this).attr('name'),
            cancel      :  i18n.cancel,
            submit      :  i18n.save,
            indicator   :  i18n.saving,
            tooltip     :  i18n.clickToEdit,
            placeholder :  i18n.clickToEdit,
            submitdata  :  {authenticity_token: AUTH_TOKEN},
            onsuccess   :  function(result, status, xhr) {
                var id = $('#provider_id');
                list.refresh(id.attr('value'), id.attr('data-ajax_url'));
            },
            onerror     :  function(settings, original, xhr) {
            original.reset();
            $("#notification").replaceWith(xhr.responseText);
            }
        });
    });
});
