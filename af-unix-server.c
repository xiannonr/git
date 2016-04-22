#include <windows.h>
#include <stdio.h>

struct client {
	int id;
	HANDLE pipe;
};

static DWORD WINAPI handle_client(LPVOID param)
{
	struct client *data = (struct client *) param;
	char buffer[1024];
	DWORD length;

	for (;;) {
		if (!ReadFile(data->pipe, buffer, sizeof(buffer), &length, NULL)
				|| length == 0) {
			fprintf(stderr, "client %d: %s\n", data->id,
				GetLastError() == ERROR_BROKEN_PIPE ?
				"broken pipe" : "read error");
			break;
		}

		buffer[length] = '\0';
		fprintf(stderr, "client %d: received %s\n", data->id, buffer);
		fflush(stderr);
		if (!strcmp(buffer, "bye")) {
			WriteFile(data->pipe, "Bye!", 4, NULL, NULL);
			break;
		}
		sprintf(buffer, "Hello, client %d!", data->id);
		WriteFile(data->pipe, buffer, strlen(buffer), NULL, NULL);
		Sleep(1000);
	}
	//FlushFilebuffers(data->pipe);
	DisconnectNamedPipe(data->pipe);
	CloseHandle(data->pipe);
}

static int serve(const char *path)
{
	int counter = 0;
	char buffer[4096];
	HANDLE pipe, thread;

	sprintf(buffer, "\\\\.\\pipe\\%s", path);

	for (;;) {
		struct client *data;

		pipe = CreateNamedPipe(buffer,
			PIPE_ACCESS_INBOUND | PIPE_ACCESS_OUTBOUND,
			PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
			PIPE_UNLIMITED_INSTANCES,
			1024, 1024, 0, NULL);
		if (pipe == INVALID_HANDLE_VALUE) {
			fprintf(stderr, "Could not create pipe %s\n", buffer);
			return -1;
		}

		if (!ConnectNamedPipe(pipe, NULL) &&
				GetLastError() != ERROR_PIPE_CONNECTED) {
			CloseHandle(pipe);
			fprintf(stderr, "Could not connect to client\n");
			continue;
		}

		data = malloc(sizeof(*data));
		data->id = ++counter;
		data->pipe = pipe;

		thread = CreateThread(NULL, 0, handle_client, (LPVOID) data,
			0, NULL);
		if (thread)
			CloseHandle(thread);
	}
}

static int client(const char *path, int argc, char **argv)
{
	char buffer[4096];
	HANDLE pipe;
	DWORD mode = PIPE_READMODE_MESSAGE, length;

	sprintf(buffer, "\\\\.\\pipe\\%s", path);

	for (;;) {
		pipe = CreateFile(buffer, GENERIC_READ | GENERIC_WRITE,
			0, NULL, OPEN_EXISTING, 0, NULL);
		if (pipe != INVALID_HANDLE_VALUE)
			break;
		if (GetLastError() != ERROR_PIPE_BUSY) {
			fprintf(stderr, "Could not open %s (%d)\n",
				path, GetLastError());
			return -1;
		}
		if (!WaitNamedPipe(buffer, 5000)) {
			fprintf(stderr, "Timed out: %s\n", path);
			CloseHandle(pipe);
			return -1;
		}
	}

	if (!SetNamedPipeHandleState(pipe, &mode, NULL, NULL)) {
		fprintf(stderr, "Could not switch pipe to message mode: %s\n",
			path);
		CloseHandle(pipe);
		return -1;
	}

	for (; argc >= 0; argc--, argv ++) {
		const char *message = argc ? *argv : "bye";

		if (!WriteFile(pipe, message, strlen(message), &length, NULL) ||
				length != strlen(message)) {
			fprintf(stderr, "Could not send '%s'\n", message);
			return -1;
		}
		for (;;) {
			if (ReadFile(pipe, buffer, sizeof(buffer),
					&length, NULL)) {
				buffer[length] = '\0';
				printf("remote: %s\n", buffer);
				fflush(stdout);
				break;
			}
			if (GetLastError() != ERROR_MORE_DATA) {
				fprintf(stderr, "Could not read from %s\n",
					path);
				CloseHandle(pipe);
				return -1;
			}
			buffer[length] = '\0';
			printf("remote (partial): %s\n", buffer);
		}
	}

	CloseHandle(pipe);
	return 0;
}

int main(int argc, char **argv)
{
	const char *path = "C:\\git-sdk-64\\usr\\src\\git";

	if (argc > 1 && !strcmp("serve", argv[1]))
		return serve(path);

	return client(path, argc - 1, argv + 1);
}
