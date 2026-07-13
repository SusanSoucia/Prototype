import type { MockMethod } from 'vite-plugin-mock';

export default [
  {
    url: '/route/getConstantRoutes',
    method: 'get',
    response: () => ({
      code: 200,
      data: [] as Api.Route.MenuRoute[],
      message: 'ok'
    })
  },
  {
    url: '/route/getUserRoutes',
    method: 'get',
    response: () => ({
      code: 200,
      data: {
        routes: [] as Api.Route.MenuRoute[],
        home: 'chats'
      } as Api.Route.UserRoute,
      message: 'ok'
    })
  },
  {
    url: '/route/isRouteExist',
    method: 'get',
    response: () => ({ code: 200, data: false, message: 'ok' })
  }
] as MockMethod[];
