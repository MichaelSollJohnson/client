const config = require("../../config.js");
const helpers = require("../../src/shared/doc-helpers.js");


describe.skip('Loading indicators', () => {
  const testEmail = 'cypress@testing.com'
  const testUserDb = 'userdb-' + helpers.toHex(testEmail);

  before(() => {
    cy.deleteUser(testEmail)
    cy.signup_blank(testEmail)

    cy.task('db:seed', { dbName: testUserDb, seedName: 'twoTrees' })

    cy.request('POST', config.TEST_SERVER + '/logout')
    cy.clearCookie('AuthSession')

    cy.login(testEmail)
  })

  beforeEach(() => {
    cy.fixture('twoTrees.ids.json').as('treeIds')
    Cypress.Cookies.preserveOnce('AuthSession')
  })

  it('Should not show "Empty" message', () => {
    cy.visit(config.TEST_SERVER)

    cy.url().should('match', /\/[a-zA-Z0-9]{5}$/)

    cy.window().then((win) => {
      expect(win.elmMessages.map(m => m.elmMessage))
        .to.not.include('EmptyMessageShown');
    })
  })
})