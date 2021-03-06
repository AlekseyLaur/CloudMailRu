# Плагин [Total Commander](http://www.ghisler.com/) для работы с [cloud.mail.ru](http://cloud.mail.ru)

### Описание
Плагином поддерживаются:
* Работа с несколькими аккаунтами
* Навигация по каталогам
* Скачивание файлов из облака
* Заливка файлов в облако
* Удаление файлов в облаке
* Переименование/перемещение файлов в облаке
* Просмотр свойств файла в облаке через набор дополнительных колонок TC 

Реализован только Unicode-набор функций, на не NT-версиях Windows плагин работать не будет.
Поддержка x64-версии TC имеется.

Перед использованием ознакомьтесь с [лицензионным соглашением по использованию Сервиса Облако@mail.ru](https://cloud.mail.ru/LA/)

### Установка и использование
Скачайте [текущий стабильный релиз](https://github.com/pozitronik/CloudMailRu/releases/latest), распакуйте его, и подключите плагин MailRuCloud.wfx/MailRuCloud.wfx64. Вызовите настройки плагина (Alt+Enter), и добавьте все необходимые аккаунты.<br/>
**Внимание:** сохраняемые пароли будут храниться в открытом виде!<br /><br/>

Пароли аккаунтов можно не указывать, в этом случае они будут запрашиваться при каждом подключении.<br />
Также возможно использование встроенного в TC менеджера паролей (опции "Store password in TC password manager" в настройках и в диалоге запроса пароля).

В случае, если при попытке соединения в окне сообщений TC будет что-то вроде<br />

 Cloud login error Could not load SSL library.

нужно скопировать библиотеки libeay32.dll/ssleay32.dll в каталог Total Commander. В репозитории приложены библиотеки для Win32, сборки для x64 можно взять тут: https://indy.fulgan.com/SSL/

### Возможные проблемы
В случае, если в системе уже присутствуют (и загружены в память) библиотеки libeay32.dll/ssleay32.dll, они могут быть использованы плагином, даже если вы хотите использовать другие их версии. В некоторых случаях это приводит к проблемам. Можно принудительно использовать библиотеки, находящиеся в каталоге плагина, в настройках плагина включив опцию "Load SSL libraries only from plugin directory".<br/>
**Полезно:** для разделения x32 и x64-версий библиотек поместите их в подкаталоги x32 и x64 соответственно.

### Licence
GNU GPL v3.0
